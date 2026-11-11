# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "fileutils"
require "yaml"
require "json"
require "open3"
require "prism"

require_relative "midi"

module Rmxp
  # Compatibility migration for pre-v19 Essentials games: copies the game,
  # extracts the scripts, applies generic transformations, then rebuilds
  # Scripts.rxdata. No game-specific fixes.
  class Migrate
    FLAGS = { "i" => "Regexp::IGNORECASE", "m" => "Regexp::MULTILINE", "x" => "Regexp::EXTENDED" }.freeze
    COMPAT = File.expand_path("preload/compat", __dir__)
    GIF_MANIFEST = "gif_frames.txt"
    GIF_SCRIPT = "9999_rmxp_gif_frames.rb"
    WEAKREF_SCRIPT = "9999_rmxp_weakref.rb"
    # gif.dll returns frame times in 1/100 s, and GifBitmap compares them with
    # a counter incremented by 2 per update. Keep the same unit.
    GIF_DELAY_UNITS = 100
    PRELOADS = %w[preload/win32_wrap.rb preload/font_installer.rb preload/ruby18_wrap.rb preload/ruby18_extra.rb
                  preload/mkxp_wrap.rb preload/hm7_fallback.rb preload/elitebattle_render.rb preload/add_stdlib.rb preload/power_cache.rb preload/tmp_env.rb preload/errno_dir.rb preload/input_ext.rb
                  preload/window_scale.rb].freeze

    Result = Struct.new(:scripts, :regexes, :dynamic_flags, :when_colons, :break_fixes,
                        :read_bytes, :proc_returns, :legacy_aliases, :skipped_scripts,
                        :parse_errors, :midis, keyword_init: true)

    def initialize(game_dir, out_dir)
      @game_dir = File.expand_path(game_dir)
      @out_dir = File.expand_path(out_dir)
    end

    def run
      raise ArgumentError, "game not found: #{@game_dir}" unless Dir.exist?(@game_dir)
      raise ArgumentError, "output already exists: #{@out_dir}" if File.exist?(@out_dir)
      check_archives

      FileUtils.mkdir_p(@out_dir)
      FileUtils.cp_r(File.join(@game_dir, "."), @out_dir)
      FileUtils.chmod_R("u+w", @out_dir)
      scripts_dir = File.join(@out_dir, "scripts")
      Rmxp::Scripts.unpack(File.join(@out_dir, "Data/Scripts.rxdata"), scripts_dir)
      skipped_scripts = skip_windows_only_scripts(scripts_dir)

      regexes = 0
      dynamic = 0
      when_colons = 0
      break_fixes = 0
      read_bytes = 0
      proc_returns = 0
      legacy_aliases = 0
      parse_errors = 0
      Dir.glob(File.join(scripts_dir, "*.rb")).sort.each do |path|
        source = File.binread(path)
        out, count, dyn, whens, breaks, bytes, returns, aliases, error = transform_source(source)
        regexes += count
        dynamic += dyn
        when_colons += whens
        break_fixes += breaks
        read_bytes += bytes
        proc_returns += returns
        legacy_aliases += aliases
        parse_errors += 1 if error
        File.binwrite(path, out) unless out == source
      end

      append_string_input_compat(scripts_dir)
      append_weakref_compat(scripts_dir)
      append_gif_frames_compat(scripts_dir) unless convert_gifs.empty?
      midis = Rmxp::Midi.convert(@out_dir)
      File.binwrite(File.join(@out_dir, "Data/Scripts.rxdata"), Rmxp::Scripts.build(@out_dir))
      install_preloads
      ensure_game_ini
      Result.new(scripts: Dir.glob(File.join(scripts_dir, "*.rb")).length,
                 regexes: regexes, dynamic_flags: dynamic, when_colons: when_colons,
                 break_fixes: break_fixes, read_bytes: read_bytes,
                 proc_returns: proc_returns, legacy_aliases: legacy_aliases,
                 skipped_scripts: skipped_scripts, parse_errors: parse_errors, midis: midis)
    end

    private

    def transform_source(source)
      source, whens = fix_when_colons(source)
      read_bytes = 0
      source = source.gsub(/read\(\s*(\d+)\s*\)\[0\]/) do
        read_bytes += 1
        "read(#{Regexp.last_match(1)}).getbyte(0)"
      end
      result = Prism.parse(source)
      return [source, 0, 0, whens, 0, read_bytes, 0, 0, true] unless result.value

      replacements = []
      queue = [result.value]
      until queue.empty?
        node = queue.shift
        if node.is_a?(Prism::RegularExpressionNode) && node.content.include?("\\x") &&
           !node.content.include?("\#{")
          replacement = if node.content.match?(/[+*{]/)
                          binary_regex_replacement(node)
                        else
                          byte_regex_replacement(node)
                        end
          replacements << [node.location.start_offset, node.location.end_offset, replacement] if replacement
        end
        node.compact_child_nodes.each { |child| queue << child }
      end

      out = source.dup
      replacements.sort_by { |start, _end, _text| -start }.each do |start, finish, text|
        out[start...finish] = text
      end

      # /n on an interpolated regexp is incompatible with Unicode regexps
      reparsed = Prism.parse(out)
      dynamic = 0
      if reparsed.value
        queue = [reparsed.value]
        dynamic_nodes = []
        until queue.empty?
          node = queue.shift
          if defined?(Prism::InterpolatedRegularExpressionNode) &&
             node.is_a?(Prism::InterpolatedRegularExpressionNode) && node.closing.include?("n")
            dynamic_nodes << node
          end
          node.compact_child_nodes.each { |child| queue << child }
        end
        dynamic_nodes.sort_by { |node| -node.location.start_offset }.each do |node|
          out[node.closing_loc.start_offset...node.closing_loc.end_offset] = "/" + node.closing[1..].delete("n")
          dynamic += 1
        end
      end
      out, breaks = fix_invalid_breaks(out)
      out, returns = fix_returns_in_blocks(out)
      out, aliases = fix_legacy_string_aliases(out)
      begin
        RubyVM::InstructionSequence.compile(out)
      rescue SyntaxError
        return [out, replacements.length, dynamic, whens, breaks, read_bytes, returns, aliases, true]
      end
      [out, replacements.length, dynamic, whens, breaks, read_bytes, returns, aliases, false]
    end

    # Ruby 1.8 accepted `when value:`; Prism reports the offending ':'. Only
    # those offsets are touched, never `::`, symbols or strings.
    def fix_when_colons(source)
      result = Prism.parse(source)
      offsets = result.errors.select { |error| error.message.include?("predicates of a `when` clause") }
                            .map { |error| error.location.start_offset }
                            .select { |offset| source.getbyte(offset) == 58 }
                            .uniq
      out = source.dup
      offsets.sort.reverse_each { |offset| out[offset] = " then" }
      [out, offsets.length]
    end

    def binary_regex_replacement(node)
      flags = node.closing.chars.filter_map { |ch| FLAGS[ch] }
      text = "Regexp.new(#{node.content.dump}.b, Regexp::NOENCODING"
      text << " | #{flags.join(' | ')}" unless flags.empty?
      text << ")"
      text
    end

    # Ruby 1.8 accepted `break`/`next` outside a loop, which no longer
    # compiles in Ruby 3. Replace them with their runtime effect
    # (LocalJumpError).
    def fix_invalid_breaks(source)
      result = Prism.parse(source)
      return [source, 0] unless result.value

      nodes = []
      walk = lambda do |node, loops, blocks, lambdas|
        case node
        when Prism::DefNode, Prism::ClassNode, Prism::ModuleNode
          node.compact_child_nodes.each { |child| walk.call(child, 0, 0, 0) }
          next
        when Prism::WhileNode, Prism::UntilNode, Prism::ForNode
          node.compact_child_nodes.each { |child| walk.call(child, loops + 1, blocks, lambdas) }
          next
        when Prism::BlockNode
          node.compact_child_nodes.each { |child| walk.call(child, loops, blocks + 1, lambdas) }
          next
        when Prism::LambdaNode
          node.compact_child_nodes.each { |child| walk.call(child, loops, blocks, lambdas + 1) }
          next
        when Prism::BreakNode, Prism::NextNode
          nodes << node if loops.zero? && (blocks.zero? || lambdas.positive?)
        end
        node.compact_child_nodes.each { |child| walk.call(child, loops, blocks, lambdas) }
      end
      walk.call(result.value, 0, 0, 0)
      out = source.dup
      nodes.sort_by { |node| -node.location.start_offset }.each do |node|
        kind = node.is_a?(Prism::BreakNode) ? "break" : "next"
        out[node.location.start_offset...node.location.end_offset] =
          "raise LocalJumpError, \"#{kind} outside loop\""
      end
      [out, nodes.length]
    end

    def byte_regex_replacement(node)
      bin = Regexp.new(node.content.b, Regexp::NOENCODING)
      points = []
      (0..0x10FFFF).each do |cp|
        next if cp.between?(0xD800, 0xDFFF)
        char = cp.chr(Encoding::UTF_8).b
        match = bin.match(char) rescue nil
        next unless match && match.begin(0).zero? && match.end(0) == char.bytesize
        points << cp
      end
      return nil if points.empty?

      ranges = []
      first = prev = points[0]
      points[1..].each do |cp|
        if cp == prev + 1
          prev = cp
        else
          ranges << [first, prev]
          first = prev = cp
        end
      end
      ranges << [first, prev]
      body = ranges.map do |a, b|
        a == b ? format("\\u%04X", a) : format("\\u%04X-\\u%04X", a, b)
      end.join
      opts = node.closing.chars.filter_map { |ch| FLAGS[ch] }.join(" | ")
      text = "Regexp.new(\"[#{body}]\""
      text << " | #{opts}" unless opts.empty?
      text << ")"
      text
    rescue RegexpError
      nil
    end

    # mkxp-z loads an RGSS archive before the loose files, and the games
    # themselves detect the archive and delete extracted data (Uranium deletes
    # Data/Constants.rxdata). Refuse a game still shipped encrypted: the user
    # must extract the archive first with an external tool.
    def check_archives
      # Pre-v19 kits ship files with Latin-1 names; match on bytes so a
      # non-UTF-8 name cannot abort the migration.
      found = Dir.children(@game_dir).select { |name| name.b.match?(/\.(rgssad|rgss2a|rgss3a)\z/i) }
      return if found.empty?

      raise ArgumentError,
            "#{@game_dir} ships #{found.join(', ')}; extract the archive first, " \
            "mkxp-z would load it instead of the migrated files"
    end

    # Ruby 1.8 allowed `return` in a Proc defined at the top level; it aborted
    # only that callback. Ruby 3 raises LocalJumpError once the defining
    # context is gone. In a block outside any method, `next` does the same
    # thing. Returns inside a method or a lambda keep their meaning.
    def fix_returns_in_blocks(source)
      result = Prism.parse(source)
      return [source, 0] unless result.value

      nodes = []
      walk = lambda do |node, defs, lambdas, blocks|
        case node
        when Prism::DefNode
          node.compact_child_nodes.each { |child| walk.call(child, defs + 1, lambdas, blocks) }
          next
        when Prism::LambdaNode
          node.compact_child_nodes.each { |child| walk.call(child, defs, lambdas + 1, blocks) }
          next
        when Prism::BlockNode
          node.compact_child_nodes.each { |child| walk.call(child, defs, lambdas, blocks + 1) }
          next
        when Prism::ReturnNode
          nodes << node if defs.zero? && lambdas.zero? && blocks.positive?
        end
        if node.is_a?(Prism::CallNode) && node.name == :lambda && node.block
          # `lambda { ... }` keeps its local return, like Ruby 1.8.
          (node.compact_child_nodes - [node.block]).each { |child| walk.call(child, defs, lambdas, blocks) }
          walk.call(node.block, defs, lambdas + 1, blocks)
          next
        end
        node.compact_child_nodes.each { |child| walk.call(child, defs, lambdas, blocks) }
      end
      walk.call(result.value, 0, 0, 0)

      out = source.dup
      nodes.sort_by { |node| -node.location.start_offset }.each do |node|
        offset = node.location.start_offset
        out[offset, 6] = "next" if out.byteslice(offset, 6) == "return"
      end
      [out, nodes.length]
    end

    # Scripts that integrate Windows-only native libraries for their audio
    # (the Community Script Project's RGSS Linker / FmodEx add-on, used by
    # several pre-v19 games). They raise LoadError on mkxp-z, which already
    # provides the audio; keep them out of the migrated script list.
    def skip_windows_only_scripts(scripts_dir)
      manifest_path = File.join(@out_dir, Rmxp::Scripts::MANIFEST)
      manifest = YAML.safe_load_file(manifest_path)
      kept = []
      skipped = 0
      manifest.fetch("scripts").each do |entry|
        path = File.join(scripts_dir, entry["file"])
        if File.file?(path) && File.binread(path).match?(/RGSSLinker_Initialize|RGSS FmodEx\.dll/)
          File.delete(path)
          skipped += 1
        else
          kept << entry
        end
      end
      manifest["scripts"] = kept
      File.write(manifest_path, YAML.dump(manifest))
      skipped
    end

    # Some scripts alias String#getbyte/setbyte/bytesize to 1.8's String#[]
    # and friends, for Ruby 1.9 code that ran on 1.8. On Ruby 3 the built-in
    # methods already have the 1.8 return values, and the aliases make
    # getbyte return a String again (which breaks migrated shims and saves).
    def fix_legacy_string_aliases(source)
      result = Prism.parse(source)
      return [source, 0] unless result.value

      legacy = { "getbyte" => "[]", "setbyte" => "[]=", "bytesize" => "size" }
      nodes = []
      queue = [result.value]
      until queue.empty?
        node = queue.shift
        if node.is_a?(Prism::AliasMethodNode) && legacy[node.new_name.unescaped] == node.old_name.unescaped
          nodes << node
        end
        queue.concat(node.compact_child_nodes)
      end

      out = source.dup
      nodes.sort_by { |node| -node.location.start_offset }.each do |node|
        start = node.location.start_offset
        stop = node.location.end_offset
        stop += 1 while out.byteslice(stop, 1) == " "
        out[start...stop] = "nil"
      end
      [out, nodes.length]
    end

    def append_string_input_compat(scripts_dir)
      file = "9999_rmxp_string_input.rb"
      File.write(File.join(scripts_dir, file), <<~RUBY)
        # SPDX-FileCopyrightText: 2026 Cheeenxiii
        # SPDX-License-Identifier: MIT
        # Ruby 1.8's String#[] and IO#getc returned a byte; Ruby 3 returns a
        # String. Covers both StringInput variants (IO subclass, or standalone
        # class with @string/@pos).
        if defined?(StringInput)
          class StringInput
            def getc
              if instance_variable_defined?(:@string) && @string
                return nil if eof?
                ch = @string[@pos]
                @pos += 1
                @pos += 1 if @pos == @string.size
                ch.is_a?(String) ? ch.getbyte(0) : ch
              else
                return nil if eof?
                byte = read(1)
                byte && byte.getbyte(0)
              end
            end
          end
        end
      RUBY
      path = File.join(@out_dir, Rmxp::Scripts::MANIFEST)
      manifest = YAML.safe_load_file(path)
      scripts = manifest.fetch("scripts")
      main = scripts.index { |entry| entry["file"].include?("Main") } || scripts.length
      scripts.insert(main, { "id" => 9_999_999, "file" => file, "name" => "rmxp compat" })
      File.write(path, YAML.dump(manifest))
    end

    # Animated GIFs in pre-v19 Essentials are decoded by a Windows gif.dll.
    # Convert them once, at migration time, to PNG frames plus a plain-text
    # manifest read by preload/gif_frames.rb at runtime.
    def convert_gifs
      gifs = Dir.glob(File.join(@out_dir, "Graphics", "**", "*.gif"), File::FNM_CASEFOLD).sort
      return [] if gifs.empty?

      unless gif_tools_available?
        warn "rmxp: ffmpeg/ffprobe not found; animated GIFs will not be converted"
        return []
      end

      converted = gifs.filter_map { |gif| convert_gif(gif) }
      write_gif_manifest(converted) unless converted.empty?
      converted
    end

    def convert_gif(gif)
      relative = relative_to_out(gif)
      base = File.basename(gif, File.extname(gif))
      frames_dir = File.join(File.dirname(gif), "#{base}.frames")
      FileUtils.rm_rf(frames_dir)
      FileUtils.mkdir_p(frames_dir)

      unless extract_gif_frames(gif, frames_dir)
        FileUtils.rm_rf(frames_dir)
        warn "rmxp: could not extract frames from #{relative}; GIF left as is"
        return nil
      end

      frames = Dir.glob(File.join(frames_dir, "frame*.png"))
      durations = probe_gif_durations(gif)
      if frames.empty? || durations.nil? || durations.length != frames.length
        FileUtils.rm_rf(frames_dir)
        warn "rmxp: could not read frame delays from #{relative}; GIF left as is"
        return nil
      end

      delays = durations.map { |duration| [(duration * GIF_DELAY_UNITS).round, 1].max }
      { "key" => "#{base}_tmp_", "dir" => relative_to_out(frames_dir), "delays" => delays }
    end

    def extract_gif_frames(gif, frames_dir)
      output = File.join(frames_dir, "frame%04d.png")
      # -fps_mode is the modern spelling; -vsync keeps older ffmpeg working.
      [["-fps_mode", "passthrough"], ["-vsync", "0"]].each do |mode|
        _out, err, status = run_tool("ffmpeg", "-y", "-v", "error", "-i", gif, *mode,
                                     "-start_number", "0", output)
        return true if status&.success?
        break if status.nil? || !err.include?("Unrecognized option")
      end
      false
    end

    # gif.dll returns cumulative frame times in 1/100 s, with the looping
    # duration appended. ffprobe reports one line per frame; older versions
    # expose pkt_duration_time, newer ones duration_time.
    def probe_gif_durations(gif)
      stdout, _err, status = run_tool(
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "frame=pkt_duration_time,duration_time", "-of", "csv=p=0", gif
      )
      return nil unless status&.success?

      durations = stdout.lines.filter_map do |line|
        line.split(",").filter_map { |value| Float(value.strip) rescue nil }.last
      end
      durations.empty? ? nil : durations
    end

    def gif_tools_available?
      %w[ffmpeg ffprobe].all? do |tool|
        _out, _err, status = Open3.capture3(tool, "-version")
        status.success?
      rescue Errno::ENOENT
        false
      end
    end

    def run_tool(*command)
      Open3.capture3(*command)
    rescue Errno::ENOENT
      [nil, "", nil]
    end

    def write_gif_manifest(entries)
      entries.group_by { |entry| entry["key"] }.each do |key, duplicates|
        warn "rmxp: several GIFs use the basename #{key}; only one frame set can load" if duplicates.length > 1
      end
      lines = ["# rmxp-modern GIF frames: key<TAB>frames dir<TAB>delays in 1/100 s"]
      entries.each do |entry|
        lines << [entry["key"], entry["dir"], entry["delays"].join(",")].join("\t")
      end
      File.write(File.join(@out_dir, GIF_MANIFEST), lines.join("\n") + "\n")
    end

    def relative_to_out(path)
      path.delete_prefix("#{@out_dir}/").tr(File::SEPARATOR, "/")
    end

    # Installed for every game; the script only acts on the old BitmapCache
    # WeakRef class.
    def append_weakref_compat(scripts_dir)
      file = WEAKREF_SCRIPT
      File.binwrite(File.join(scripts_dir, file), File.binread(File.join(COMPAT, "weakref_id2ref.rb")))
      path = File.join(@out_dir, Rmxp::Scripts::MANIFEST)
      manifest = YAML.safe_load_file(path)
      scripts = manifest.fetch("scripts")
      main = scripts.index do |entry|
        File.basename(entry["file"], ".rb").sub(/\A\d+_/, "") == "Main"
      end
      main ||= scripts.index { |entry| entry["file"].include?("Main") } || scripts.length
      scripts.insert(main, { "id" => 9_999_997, "file" => file, "name" => "rmxp compat" })
      File.write(path, YAML.dump(manifest))
    end

    def append_gif_frames_compat(scripts_dir)
      file = GIF_SCRIPT
      File.binwrite(File.join(scripts_dir, file), File.binread(File.join(COMPAT, "gif_frames.rb")))
      path = File.join(@out_dir, Rmxp::Scripts::MANIFEST)
      manifest = YAML.safe_load_file(path)
      scripts = manifest.fetch("scripts")
      main = scripts.index do |entry|
        File.basename(entry["file"], ".rb").sub(/\A\d+_/, "") == "Main"
      end
      main ||= scripts.index { |entry| entry["file"].include?("Main") } || scripts.length
      scripts.insert(main, { "id" => 9_999_998, "file" => file, "name" => "rmxp compat" })
      File.write(path, YAML.dump(manifest))
    end

    def install_preloads
      FileUtils.mkdir_p(File.join(@out_dir, "preload"))
      Dir.glob(File.join(COMPAT, "*.rb")).each do |path|
        FileUtils.cp(path, File.join(@out_dir, "preload", File.basename(path)))
      end
      config_path = File.join(@out_dir, "mkxp.json")
      text = File.file?(config_path) ? File.read(config_path) : "{\n}\n"
      if text =~ /"preloadScript"\s*:\s*\[(.*?)\]/m
        existing = Regexp.last_match(1)
        added = PRELOADS.reject { |entry| existing.include?(entry) }
        unless added.empty?
          list = (existing.strip.split(",").map(&:strip).reject(&:empty?) + added.map(&:inspect)).join(", ")
          text = text.sub(/"preloadScript"\s*:\s*\[.*?\]/m, "\"preloadScript\": [#{list}]")
        end
      else
        insertion = "  \"preloadScript\": [#{PRELOADS.map(&:inspect).join(', ')}],\n"
        text = text.sub(/^(\s*\{\s*\n)/) { "#{Regexp.last_match(1)}#{insertion}" }
      end
      File.write(config_path, text)
    end

    def ensure_game_ini
      path = File.join(@out_dir, "Game.ini")
      return if File.file?(path)

      title = File.basename(@out_dir)
      File.write(path, "[Game]\r\nLibrary=RGSS102E.dll\r\nScripts=Data\\Scripts.rxdata\r\nTitle=#{title}\r\nRTP1=\r\nRTP2=\r\nRTP3=\r\n")
    end
  end
end
