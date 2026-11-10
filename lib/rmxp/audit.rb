# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "prism"

module Rmxp
  # Static inventory of dynamic Ruby, in three classes:
  # - static: the target is known at build time (literal, string/symbol,
  #   alias, event fragment) and a transformation can replace it with a
  #   direct call or generated code;
  # - enumerable: the target is computed but stays within a finite set known
  #   at build time (module constant, method family, ivars of a class);
  # - dynamic: the target is unbounded at build time (arbitrary eval,
  #   ObjectSpace, variable receiver...).
  class Audit
    CATEGORIES = {
      eval: "eval (literal string)",
      eval_block: "eval (block)",
      send: "send / __send__ / public_send",
      alias: "alias / alias_method",
      define_method: "define_method",
      method_missing: "method_missing",
      marshal_load: "Marshal.load",
      marshal_dump: "Marshal.dump",
      const: "const_get / const_set",
      ivar: "instance_variable_get / set",
      object_space: "ObjectSpace",
    }.freeze

    Result = Struct.new(:scripts, :event_fragments, :parse_errors, :stats, keyword_init: true)

    def initialize(game_dir, work_dir)
      @game_dir = game_dir
      @work_dir = work_dir
    end

    def run
      project = File.join(@work_dir, "unpacked")
      Project.new(@game_dir).unpack(@game_dir, project)

      stats = { static: Hash.new(0), enumerable: Hash.new(0), dynamic: Hash.new(0) }
      scripts = 0
      parse_errors = 0

      [File.join(project, "scripts"), File.join(project, "scripts_tree")].each do |dir|
        next unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |path|
          scripts += 1
          parse_errors += count(File.binread(path), stats)
        end
      end

      event_fragments = audit_events(File.join(@game_dir, "Data"), stats, -> { parse_errors += 1 })
      Result.new(scripts: scripts, event_fragments: event_fragments,
                 parse_errors: parse_errors, stats: stats)
    end

    # Audits a directory of already extracted scripts (PSDK, for instance).
    def run_scripts_dir(dir)
      stats = { static: Hash.new(0), enumerable: Hash.new(0), dynamic: Hash.new(0) }
      scripts = 0
      parse_errors = 0
      Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |path|
        scripts += 1
        parse_errors += count(File.binread(path), stats)
      end
      Result.new(scripts: scripts, event_fragments: 0,
                 parse_errors: parse_errors, stats: stats)
    end

    private

    def count(source, stats)
      result = Prism.parse(source)
      return 1 unless result.success?

      counter = Counter.new
      counter.visit(result.value)
      counter.static.each { |key, value| stats[:static][key] += value }
      counter.enumerable.each { |key, value| stats[:enumerable][key] += value }
      counter.dynamic.each { |key, value| stats[:dynamic][key] += value }
      0
    end

    def audit_events(data_dir, stats, on_parse_error)
      return 0 unless Dir.exist?(data_dir)

      fragments = 0
      files = Dir.children(data_dir).sort.select do |name|
        name.match?(/\A(Map\d+\.rxdata|CommonEvents\.rxdata|Troops\.rxdata)\z/)
      end
      files.each do |name|
        raw = File.binread(File.join(data_dir, name))
        next unless Codec.marshal?(raw)

        Codec.reset_stubs!
        begin
          object = Codec.load_bytes(raw)
        rescue StandardError
          next
        end
        each_event_list(object, {}) do |list|
          index = 0
          while index < list.length
            command = list[index]
            code = command.instance_variable_get(:@code)
            parameters = command.instance_variable_get(:@parameters)
            if [355, 655].include?(code)
              source = +""
              while index < list.length
                current = list[index]
                break unless [355, 655].include?(current.instance_variable_get(:@code))

                source << current.instance_variable_get(:@parameters)[0].to_s << "\n"
                index += 1
              end
              fragments += 1
              on_parse_error.call if count(source, stats) == 1
            elsif code == 111 && parameters.is_a?(Array) && parameters[0] == 12
              fragments += 1
              count(parameters[1].to_s, stats)
              index += 1
            else
              index += 1
            end
          end
        end
      end
      fragments
    end

    def each_event_list(object, visited, &block)
      case object
      when Array
        id = object.object_id
        return if visited[id]

        visited[id] = true
        if !object.empty? && object[0].class.name == "RPG::EventCommand"
          yield object
        else
          object.each { |child| each_event_list(child, visited, &block) }
        end
      when Hash
        id = object.object_id
        return if visited[id]

        visited[id] = true
        object.each { |_key, child| each_event_list(child, visited, &block) }
      when String, Integer, Float, Symbol, TrueClass, FalseClass, NilClass
        nil
      else
        id = object.object_id
        return if visited[id]

        visited[id] = true
        object.instance_variables.each do |ivar|
          each_event_list(object.instance_variable_get(ivar), visited, &block)
        end
      end
    end

    class Counter < Prism::Visitor
      attr_reader :static, :enumerable, :dynamic

      def initialize
        super
        @static = Hash.new(0)
        @enumerable = Hash.new(0)
        @dynamic = Hash.new(0)
      end

      def constant_receiver?(node)
        node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)
      end

      def literal?(node)
        node.is_a?(Prism::SymbolNode) || node.is_a?(Prism::StringNode) ||
          node.is_a?(Prism::IntegerNode)
      end

      def first_argument(node)
        node.arguments&.arguments&.first
      end

      def visit_call_node(node)
        case node.name
        when :eval
          literal?(first_argument(node)) ? @static[:eval] += 1 : @dynamic[:eval] += 1
        when :instance_eval, :class_eval, :module_eval
          first = first_argument(node)
          if first.nil? || literal?(first)
            @static[:eval_block] += 1
          else
            @dynamic[:eval_block] += 1
          end
        when :send, :__send__, :public_send
          if literal?(first_argument(node))
            @static[:send] += 1
          elsif constant_receiver?(node.receiver)
            @enumerable[:send] += 1
          else
            @dynamic[:send] += 1
          end
        when :define_method
          literal?(first_argument(node)) ? @static[:define_method] += 1 : @enumerable[:define_method] += 1
        when :alias_method
          literal?(first_argument(node)) ? @static[:alias] += 1 : @enumerable[:alias] += 1
        when :const_get, :const_set
          if literal?(first_argument(node))
            @static[:const] += 1
          elsif constant_receiver?(node.receiver)
            @enumerable[:const] += 1
          else
            @dynamic[:const] += 1
          end
        when :instance_variable_get, :instance_variable_set
          literal?(first_argument(node)) ? @static[:ivar] += 1 : @enumerable[:ivar] += 1
        when :load
          if constant_named?(node.receiver, :Marshal)
            @static[:marshal_load] += 1
          end
        when :dump
          if constant_named?(node.receiver, :Marshal)
            @dynamic[:marshal_dump] += 1
          end
        end
        @dynamic[:object_space] += 1 if constant_named?(node.receiver, :ObjectSpace)
        super
      end

      def visit_alias_method_node(node)
        @static[:alias] += 1
        super
      end

      def visit_def_node(node)
        @enumerable[:method_missing] += 1 if node.name == :method_missing
        super
      end

      def constant_named?(node, name)
        node.is_a?(Prism::ConstantReadNode) && node.name == name
      end
    end
  end
end
