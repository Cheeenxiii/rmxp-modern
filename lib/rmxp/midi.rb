# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "fileutils"
require "open3"

module Rmxp
  # Renders a game's MIDI music to OGG in place, once, so platforms without a
  # MIDI synth (the Switch port skips MIDI) still have music. The game's own
  # soundfont is used; the .mid files are kept next to the .ogg ones.
  module Midi
    module_function

    # Converts every Audio/**/*.mid|midi under dir. Returns the number of
    # files converted. Warns once and does nothing when the tools or the
    # soundfont are missing.
    def convert(dir)
      midis = Dir.glob(File.join(dir, "Audio", "**", "*.{mid,midi}"), File::FNM_CASEFOLD).sort
      return 0 if midis.empty?

      soundfont = find_soundfont(dir)
      unless soundfont
        warn "rmxp: no .sf2 soundfont in the game; MIDI files will not be converted"
        return 0
      end

      renderer = renderer()
      unless renderer && tool_available?("ffmpeg")
        warn "rmxp: fluidsynth, timidity or ffmpeg not found; MIDI files will not be converted"
        return 0
      end

      midis.count do |midi|
        ogg = midi.sub(/\.midi?\z/i, ".ogg")
        # A previous conversion (console build, package) is reused.
        next true if File.file?(ogg) && File.mtime(ogg) >= File.mtime(midi)

        convert_one(dir, midi, soundfont, renderer)
      end
    end

    def find_soundfont(dir)
      local = Dir.glob(File.join(dir, "*.sf2"), File::FNM_CASEFOLD).sort
      audio = Dir.glob(File.join(dir, "Audio", "**", "*.sf2"), File::FNM_CASEFOLD).sort
      (local + audio).find { |path| File.size?(path) }
    end

    def renderer
      return "fluidsynth" if tool_available?("fluidsynth")
      return "timidity" if tool_available?("timidity")

      nil
    end

    def tool_available?(tool)
      Open3.capture3(tool, "-version")
      true
    rescue Errno::ENOENT
      false
    end

    def convert_one(dir, midi, soundfont, renderer)
      relative = midi.delete_prefix("#{dir}/")
      ogg = midi.sub(/\.midi?\z/i, ".ogg")
      wav = "#{midi}.rmxp-tmp.wav"
      if renderer == "fluidsynth"
        _out, err, status = Open3.capture3(renderer, "-ni", "-F", wav, "-r", "44100", soundfont, midi)
      else
        _out, err, status = Open3.capture3(renderer, "-Ow", "-o", wav, midi)
      end
      if !status.success? || !File.size?(wav)
        warn "rmxp: could not render #{relative}#{tool_error(err)}; MIDI left as is"
        return false
      end

      _out, err, status = Open3.capture3("ffmpeg", "-y", "-v", "error", "-i", wav,
                                         "-c:a", "libvorbis", "-q:a", "4", ogg)
      if !status.success? || !File.size?(ogg)
        FileUtils.rm_f(ogg)
        warn "rmxp: could not encode #{relative} to OGG#{tool_error(err)}; MIDI left as is"
        return false
      end
      true
    ensure
      FileUtils.rm_f(wav) if wav
    end

    def tool_error(text)
      line = text.to_s.lines.first.to_s.strip
      line.empty? ? "" : " (#{line})"
    end
  end
end
