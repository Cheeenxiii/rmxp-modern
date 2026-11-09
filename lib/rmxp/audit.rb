require "prism"

module Rmxp
  # Inventaire statique du Ruby dynamique : eval, send calculés, alias,
  # define_method, method_missing, Marshal. Sert au jalon d'audit : il donne
  # des ordres de grandeur par jeu, pas une preuve d'exhaustivité.
  class Audit
    CATEGORIES = %i[
      eval eval_string eval_block send_literal send_dynamic define_method
      method_missing alias alias_update marshal const_get const_set
      instance_variable_get instance_variable_set ObjectSpace
    ].freeze

    def initialize(game_dir, work_dir)
      @game_dir = game_dir
      @work_dir = work_dir
    end

    def run
      project = File.join(@work_dir, "unpacked")
      Project.new(@game_dir).unpack(@game_dir, project)

      @stats = Hash.new(0)
      @alias_update_files = []
      @sources = 0

      audit_dir(File.join(project, "scripts"))
      tree = File.join(project, "scripts_tree")
      audit_dir(tree, prefix: "Scripts/") if Dir.exist?(tree)
      audit_events(File.join(@game_dir, "Data"))

      { stats: @stats, sources: @sources, alias_update_files: @alias_update_files.uniq }
    end

    private

    def audit_dir(dir, prefix: "")
      return unless Dir.exist?(dir)

      Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |path|
        source = File.binread(path)
        @sources += 1
        name = prefix + path.sub(dir + "/", "")
        audit_source(source, name)
      end
    end

    def audit_events(data_dir)
      return unless Dir.exist?(data_dir)

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
              @sources += 1
              audit_source(source, "event:#{name}")
            elsif code == 111 && parameters.is_a?(Array) && parameters[0] == 12
              @sources += 1
              audit_source(parameters[1].to_s, "event:#{name}")
              index += 1
            else
              index += 1
            end
          end
        end
      end
    end

    def audit_source(source, name)
      result = Prism.parse(source)
      return unless result.success?

      counter = Counter.new
      counter.visit(result.value)
      counter.stats.each { |key, value| @stats[key] += value }
      if counter.stats[:alias_update].positive?
        @alias_update_files << name
      end
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
      attr_reader :stats

      def initialize
        super
        @stats = Hash.new(0)
      end

      def visit_call_node(node)
        case node.name
        when :eval
          @stats[:eval] += 1
        when :instance_eval, :class_eval, :module_eval
          first = node.arguments&.arguments&.first
          @stats[first.is_a?(Prism::StringNode) ? :eval_string : :eval_block] += 1
        when :send, :__send__, :public_send
          first = node.arguments&.arguments&.first
          literal = first.is_a?(Prism::SymbolNode) || first.is_a?(Prism::StringNode)
          @stats[literal ? :send_literal : :send_dynamic] += 1
        when :define_method
          @stats[:define_method] += 1
        when :alias_method
          @stats[:alias] += 1
        when :const_get
          @stats[:const_get] += 1
        when :const_set
          @stats[:const_set] += 1
        when :instance_variable_get
          @stats[:instance_variable_get] += 1
        when :instance_variable_set
          @stats[:instance_variable_set] += 1
        when :load, :dump
          if node.receiver.is_a?(Prism::ConstantReadNode) && node.receiver.name == :Marshal
            @stats[:marshal] += 1
          end
        end
        if node.receiver.is_a?(Prism::ConstantReadNode) && node.receiver.name == :ObjectSpace
          @stats[:ObjectSpace] += 1
        end
        super
      end

      def visit_alias_method_node(node)
        @stats[:alias] += 1
        names = [node.new_name, node.old_name].select { |n| n.is_a?(Prism::SymbolNode) }.map(&:unescaped)
        @stats[:alias_update] += 1 if names.include?("update")
        super
      end

      def visit_def_node(node)
        @stats[:method_missing] += 1 if node.name == :method_missing
        super
      end
    end
  end
end
