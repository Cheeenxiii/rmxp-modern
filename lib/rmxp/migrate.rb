require "fileutils"
require "json"
require "prism"

module Rmxp
  # Migration de compatibilité d'un jeu Essentials pré-v19 : copie le jeu,
  # externalise les scripts, applique des transformations génériques, puis
  # reconstruit Scripts.rxdata. Aucune correction propre à un jeu.
  class Migrate
    FLAGS = { "i" => "Regexp::IGNORECASE", "m" => "Regexp::MULTILINE", "x" => "Regexp::EXTENDED" }.freeze
    COMPAT = File.expand_path("preload/compat", __dir__)
    PRELOADS = %w[preload/win32_wrap.rb preload/ruby18_wrap.rb preload/ruby18_extra.rb
                  preload/mkxp_wrap.rb preload/add_stdlib.rb preload/power_cache.rb].freeze

    Result = Struct.new(:scripts, :regexes, :dynamic_flags, :when_colons, :parse_errors, keyword_init: true)

    def initialize(game_dir, out_dir)
      @game_dir = File.expand_path(game_dir)
      @out_dir = File.expand_path(out_dir)
    end

    def run
      raise ArgumentError, "jeu absent: #{@game_dir}" unless Dir.exist?(@game_dir)
      raise ArgumentError, "sortie existante: #{@out_dir}" if File.exist?(@out_dir)

      FileUtils.mkdir_p(@out_dir)
      FileUtils.cp_r(File.join(@game_dir, "."), @out_dir)
      scripts_dir = File.join(@out_dir, "scripts")
      Rmxp::Scripts.unpack(File.join(@out_dir, "Data/Scripts.rxdata"), scripts_dir)

      regexes = 0
      dynamic = 0
      when_colons = 0
      parse_errors = 0
      Dir.glob(File.join(scripts_dir, "*.rb")).sort.each do |path|
        source = File.binread(path)
        out, count, dyn, whens, error = transform_source(source)
        regexes += count
        dynamic += dyn
        when_colons += whens
        parse_errors += 1 if error
        File.binwrite(path, out) unless out == source
      end

      File.binwrite(File.join(@out_dir, "Data/Scripts.rxdata"), Rmxp::Scripts.build(@out_dir))
      install_preloads
      ensure_game_ini
      Result.new(scripts: Dir.glob(File.join(scripts_dir, "*.rb")).length,
                 regexes: regexes, dynamic_flags: dynamic, when_colons: when_colons,
                 parse_errors: parse_errors)
    end

    private

    def transform_source(source)
      whens = 0
      source = source.lines.map do |line|
        replaced = line.sub(/^(\s*)when\s+((?:[^:\n]|:(?!:))+?):(?!:)([ \t]*)(.*)$/) do
          whens += 1
          "#{Regexp.last_match(1)}when #{Regexp.last_match(2)} then#{Regexp.last_match(3)}#{Regexp.last_match(4)}"
        end
        replaced
      end.join

      result = Prism.parse(source)
      return [source, 0, 0, whens, true] unless result.value

      replacements = []
      queue = [result.value]
      until queue.empty?
        node = queue.shift
        if node.is_a?(Prism::RegularExpressionNode) && node.content.include?("\\x") &&
           !node.content.include?("\#{") && !node.content.match?(/[+*{]/)
          replacement = byte_regex_replacement(node)
          replacements << [node.location.start_offset, node.location.end_offset, replacement] if replacement
        end
        node.compact_child_nodes.each { |child| queue << child }
      end

      out = source.dup
      replacements.sort_by { |start, _end, _text| -start }.each do |start, finish, text|
        out[start...finish] = text
      end

      # /n sur une regexp interpolée : incompatible avec les regexp Unicode
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
      [out, replacements.length, dynamic, whens, false]
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
