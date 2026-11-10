# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "fileutils"
require "yaml"
require "json"
require "prism"

module Rmxp
  # Compatibility migration for pre-v19 Essentials games: copies the game,
  # extracts the scripts, applies generic transformations, then rebuilds
  # Scripts.rxdata. No game-specific fixes.
  class Migrate
    FLAGS = { "i" => "Regexp::IGNORECASE", "m" => "Regexp::MULTILINE", "x" => "Regexp::EXTENDED" }.freeze
    COMPAT = File.expand_path("preload/compat", __dir__)
    PRELOADS = %w[preload/win32_wrap.rb preload/ruby18_wrap.rb preload/ruby18_extra.rb
                  preload/mkxp_wrap.rb preload/add_stdlib.rb preload/power_cache.rb preload/tmp_env.rb preload/errno_dir.rb preload/input_ext.rb].freeze

    Result = Struct.new(:scripts, :regexes, :dynamic_flags, :when_colons, :break_fixes,
                        :read_bytes, :parse_errors, keyword_init: true)

    def initialize(game_dir, out_dir)
      @game_dir = File.expand_path(game_dir)
      @out_dir = File.expand_path(out_dir)
    end

    def run
      raise ArgumentError, "game not found: #{@game_dir}" unless Dir.exist?(@game_dir)
      raise ArgumentError, "output already exists: #{@out_dir}" if File.exist?(@out_dir)

      FileUtils.mkdir_p(@out_dir)
      FileUtils.cp_r(File.join(@game_dir, "."), @out_dir)
      FileUtils.chmod_R("u+w", @out_dir)
      scripts_dir = File.join(@out_dir, "scripts")
      Rmxp::Scripts.unpack(File.join(@out_dir, "Data/Scripts.rxdata"), scripts_dir)

      regexes = 0
      dynamic = 0
      when_colons = 0
      break_fixes = 0
      read_bytes = 0
      parse_errors = 0
      Dir.glob(File.join(scripts_dir, "*.rb")).sort.each do |path|
        source = File.binread(path)
        out, count, dyn, whens, breaks, bytes, error = transform_source(source)
        regexes += count
        dynamic += dyn
        when_colons += whens
        break_fixes += breaks
        read_bytes += bytes
        parse_errors += 1 if error
        File.binwrite(path, out) unless out == source
      end

      append_string_input_compat(scripts_dir)
      File.binwrite(File.join(@out_dir, "Data/Scripts.rxdata"), Rmxp::Scripts.build(@out_dir))
      install_preloads
      ensure_game_ini
      Result.new(scripts: Dir.glob(File.join(scripts_dir, "*.rb")).length,
                 regexes: regexes, dynamic_flags: dynamic, when_colons: when_colons,
                 break_fixes: break_fixes, read_bytes: read_bytes, parse_errors: parse_errors)
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
      return [source, 0, 0, whens, 0, read_bytes, true] unless result.value

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
      begin
        RubyVM::InstructionSequence.compile(out)
      rescue SyntaxError
        return [out, replacements.length, dynamic, whens, breaks, read_bytes, true]
      end
      [out, replacements.length, dynamic, whens, breaks, read_bytes, false]
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
