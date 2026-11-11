#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Regression tests for the bin/rmxp migrate transformations.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rmxp"
require "tmpdir"
require "fileutils"
require "stringio"

migrate = Rmxp::Migrate.allocate
cases = {
  "case x\nwhen 0: y=1\nend\n" => "case x\nwhen 0 then y=1\nend\n",
  "case x\nwhen IO::SEEK_SET then y=1\nend\n" => "case x\nwhen IO::SEEK_SET then y=1\nend\n",
  "case x\nwhen :foo then y=1\nend\n" => "case x\nwhen :foo then y=1\nend\n",
  "def f\n  return 1\n  break\nend\n" => "def f\n  return 1\n  raise LocalJumpError, \"break outside loop\"\nend\n",
  "case x\nwhen 0: y\nend\n" => "case x\nwhen 0 then y\nend\n",
  "x = f.read(1)[0]\n" => "x = f.read(1).getbyte(0)\n",
  "class String\n  alias getbyte []\nend\n" => "class String\n  nil\nend\n",
  "class String\n  alias setbyte []= \nend\n" => "class String\n  nil\nend\n",
  "class String\n  alias getbyte other\nend\n" => "class String\n  alias getbyte other\nend\n",
  "g { return 1 }\n" => "g { next 1 }\n",
  "p = proc {\n  return if x\n  1\n}\n" => "p = proc {\n  next if x\n  1\n}\n",
  "def f\n  g { return 1 }\nend\n" => "def f\n  g { return 1 }\nend\n",
  "l = lambda { return 1 }\n" => "l = lambda { return 1 }\n",
}
failures = 0
cases.each do |source, expected|
  got, = migrate.send(:transform_source, source)
  next if got == expected

  failures += 1
  puts "FAIL\nexpected: #{expected.inspect}\ngot:      #{got.inspect}"
end

# A pre-v19 kit ships Latin-1 file names; reading the directory must not
# raise on an invalid UTF-8 byte sequence.
latin_dir = Dir.mktmpdir("rmxp-migrate-latin")
begin
  File.binwrite(File.join(latin_dir, "Pok\xE9mon Essentials Wiki.URL"), "")
  checker = Rmxp::Migrate.allocate
  checker.instance_variable_set(:@game_dir, latin_dir)
  checker.send(:check_archives)
rescue StandardError => e
  failures += 1
  puts "FAIL non-UTF-8 file name: #{e.class}: #{e.message}"
ensure
  FileUtils.remove_entry(latin_dir)
end

archive_dir = Dir.mktmpdir("rmxp-migrate-archive")
begin
  File.write(File.join(archive_dir, "Game.rgssad"), "")
  begin
    Rmxp::Migrate.new(archive_dir, File.join(archive_dir, "out")).run
    failures += 1
    puts "FAIL a source with Game.rgssad was not refused"
  rescue ArgumentError => e
    raise unless e.message.include?("extract the archive")
  end
ensure
  FileUtils.remove_entry(archive_dir)
end

# GIF conversion: a tiny animated GIF becomes PNG frames plus a manifest.
if system("ffmpeg", "-version", out: File::NULL, err: File::NULL) &&
   system("ffprobe", "-version", out: File::NULL, err: File::NULL)
  gif_dir = Dir.mktmpdir("rmxp-migrate-gif")
  begin
    pictures = File.join(gif_dir, "Graphics", "Pictures")
    FileUtils.mkdir_p(pictures)
    gif = File.join(pictures, "tiny.gif")
    if system("ffmpeg", "-y", "-v", "error", "-f", "lavfi",
              "-i", "testsrc=size=8x8:rate=10:duration=0.4", "-loop", "0", gif,
              out: File::NULL, err: File::NULL)
      converter = Rmxp::Migrate.allocate
      converter.instance_variable_set(:@out_dir, gif_dir)
      converted = converter.send(:convert_gifs)
      frames = Dir.glob(File.join(pictures, "tiny.frames", "frame*.png"))
      manifest = File.join(gif_dir, "gif_frames.txt")
      line = if File.file?(manifest)
               File.readlines(manifest).find { |entry| entry.start_with?("tiny_tmp_") }
             end
      dir, delays = line.to_s.chomp.split("\t")[1, 2]
      expected = converted.length == 1 && frames.length == 4 &&
                 dir == "Graphics/Pictures/tiny.frames" && delays == "10,10,10,10"
      unless expected
        failures += 1
        puts "FAIL gif conversion: converted=#{converted.inspect} frames=#{frames.length} manifest=#{line.inspect}"
      end
    else
      puts "migrate: gif test skipped (ffmpeg could not create a GIF)"
    end
  ensure
    FileUtils.remove_entry(gif_dir)
  end
else
  puts "migrate: gif test skipped (ffmpeg not found)"
end

# MIDI conversion: a game soundfont plus a renderer must produce an .ogg next
# to the original .mid. The renderer is faked on PATH, so the test does not
# need fluidsynth; the conversion goes through ffmpeg.
TINY_MIDI = ("MThd\x00\x00\x00\x06\x00\x00\x00\x01\x00\x60" \
             "MTrk\x00\x00\x00\x0C\x00\x90\x3C\x64\x60\x80\x3C\x00\x00\xFF\x2F\x00").b
FAKE_FLUIDSYNTH = <<~'RUBY'
  #!/usr/bin/env ruby
  args = ARGV
  index = args.index("-F")
  exit 0 unless index

  rate = 44_100
  samples = rate / 4
  pcm = Array.new(samples) { |i| (Math.sin(2 * Math::PI * 440 * i / rate) * 8000).to_i }.pack("s<*")
  wav = "RIFF" + [36 + pcm.bytesize].pack("V") + "WAVEfmt " +
        [16, 1, 1, rate, rate * 2, 2, 16].pack("VvvVVvv") +
        "data" + [pcm.bytesize].pack("V") + pcm
  File.binwrite(args[index + 1], wav)
RUBY

midi_dir = Dir.mktmpdir("rmxp-migrate-midi")
begin
  game = File.join(midi_dir, "game")
  FileUtils.mkdir_p(File.join(game, "Audio", "BGM"))
  FileUtils.mkdir_p(File.join(game, "Audio", "ME"))
  File.binwrite(File.join(game, "Audio", "BGM", "Theme.mid"), TINY_MIDI)
  File.binwrite(File.join(game, "Audio", "ME", "End.midi"), TINY_MIDI)
  File.write(File.join(game, "soundfont.sf2"), "sf2")

  old_path = ENV["PATH"]
  old_stderr = $stderr
  begin
    # No renderer on PATH: warn once, convert nothing, keep the .mid files.
    ENV["PATH"] = File.join(midi_dir, "empty-bin")
    FileUtils.mkdir_p(ENV["PATH"])
    warnings = StringIO.new
    $stderr = warnings
    converted = Rmxp::Midi.convert(game)
    $stderr = old_stderr
    expected = converted.zero? && warnings.string.include?("not found") &&
               File.exist?(File.join(game, "Audio", "BGM", "Theme.mid")) &&
               Dir.glob(File.join(game, "Audio", "**", "*.ogg")).empty?
    unless expected
      failures += 1
      puts "FAIL midi without renderer: converted=#{converted.inspect} stderr=#{warnings.string.inspect}"
    end

    ENV["PATH"] = old_path
    fake_bin = File.join(midi_dir, "bin")
    FileUtils.mkdir_p(fake_bin)
    fake = File.join(fake_bin, "fluidsynth")
    File.write(fake, FAKE_FLUIDSYNTH)
    File.chmod(0o755, fake)

    # A game without a soundfont is left alone, with one warning.
    no_sf2 = File.join(midi_dir, "no-sf2")
    FileUtils.mkdir_p(File.join(no_sf2, "Audio", "BGM"))
    File.binwrite(File.join(no_sf2, "Audio", "BGM", "Only.mid"), TINY_MIDI)
    ENV["PATH"] = "#{fake_bin}:#{old_path}"
    warnings = StringIO.new
    $stderr = warnings
    converted = Rmxp::Midi.convert(no_sf2)
    $stderr = old_stderr
    expected = converted.zero? && warnings.string.include?("no .sf2 soundfont") &&
               File.exist?(File.join(no_sf2, "Audio", "BGM", "Only.mid")) &&
               Dir.glob(File.join(no_sf2, "Audio", "**", "*.ogg")).empty?
    unless expected
      failures += 1
      puts "FAIL midi without soundfont: converted=#{converted.inspect} stderr=#{warnings.string.inspect}"
    end

    if system("ffmpeg", "-version", out: File::NULL, err: File::NULL)
      converted = Rmxp::Midi.convert(game)
      oggs = Dir.glob(File.join(game, "Audio", "**", "*.ogg")).sort
      expected = converted == 2 && oggs.length == 2 &&
                 oggs.all? { |path| File.size?(path) } &&
                 File.exist?(File.join(game, "Audio", "BGM", "Theme.mid")) &&
                 File.exist?(File.join(game, "Audio", "ME", "End.midi")) &&
                 Dir.glob(File.join(game, "Audio", "**", "*.wav")).empty?
      unless expected
        failures += 1
        puts "FAIL midi conversion: converted=#{converted.inspect} oggs=#{oggs.inspect}"
      end
    else
      puts "migrate: midi conversion test skipped (ffmpeg not found)"
    end
  ensure
    $stderr = old_stderr
    ENV["PATH"] = old_path
  end
ensure
  FileUtils.remove_entry(midi_dir)
end

puts failures.zero? ? "migrate: ok" : "migrate: #{failures} failure(s)"
exit(failures.zero? ? 0 : 1)
