require "prism"

module Rmxp
  # Inventaire statique du Ruby dynamique, classé :
  # - supprimable : la cible est connue au build (littéral, chaîne/symbole,
  #   alias, fragment d'événement) et une transformation peut la remplacer par
  #   un appel direct ou du code généré ;
  # - énumérable : la cible est calculée mais reste dans un ensemble fini connu
  #   au build (constante de module, famille de méthodes, ivars d'une classe) ;
  # - dynamique : la cible n'est pas bornée au build (eval arbitraire,
  #   ObjectSpace, récepteur variable…).
  class Audit
    CATEGORIES = {
      eval: "eval (chaîne littérale)",
      eval_block: "eval (bloc)",
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

      stats = { supprimable: Hash.new(0), enumerable: Hash.new(0), dynamique: Hash.new(0) }
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

    # Audit d'une arborescence de scripts déjà extraite (PSDK par exemple).
    def run_scripts_dir(dir)
      stats = { supprimable: Hash.new(0), enumerable: Hash.new(0), dynamique: Hash.new(0) }
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
      counter.supprimable.each { |key, value| stats[:supprimable][key] += value }
      counter.enumerable.each { |key, value| stats[:enumerable][key] += value }
      counter.dynamique.each { |key, value| stats[:dynamique][key] += value }
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
      attr_reader :supprimable, :enumerable, :dynamique

      def initialize
        super
        @supprimable = Hash.new(0)
        @enumerable = Hash.new(0)
        @dynamique = Hash.new(0)
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
          literal?(first_argument(node)) ? @supprimable[:eval] += 1 : @dynamique[:eval] += 1
        when :instance_eval, :class_eval, :module_eval
          first = first_argument(node)
          if first.nil? || literal?(first)
            @supprimable[:eval_block] += 1
          else
            @dynamique[:eval_block] += 1
          end
        when :send, :__send__, :public_send
          if literal?(first_argument(node))
            @supprimable[:send] += 1
          elsif constant_receiver?(node.receiver)
            @enumerable[:send] += 1
          else
            @dynamique[:send] += 1
          end
        when :define_method
          literal?(first_argument(node)) ? @supprimable[:define_method] += 1 : @enumerable[:define_method] += 1
        when :alias_method
          literal?(first_argument(node)) ? @supprimable[:alias] += 1 : @enumerable[:alias] += 1
        when :const_get, :const_set
          if literal?(first_argument(node))
            @supprimable[:const] += 1
          elsif constant_receiver?(node.receiver)
            @enumerable[:const] += 1
          else
            @dynamique[:const] += 1
          end
        when :instance_variable_get, :instance_variable_set
          literal?(first_argument(node)) ? @supprimable[:ivar] += 1 : @enumerable[:ivar] += 1
        when :load
          if constant_named?(node.receiver, :Marshal)
            @supprimable[:marshal_load] += 1
          end
        when :dump
          if constant_named?(node.receiver, :Marshal)
            @dynamique[:marshal_dump] += 1
          end
        end
        @dynamique[:object_space] += 1 if constant_named?(node.receiver, :ObjectSpace)
        super
      end

      def visit_alias_method_node(node)
        @supprimable[:alias] += 1
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
