# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "prism"

module Rmxp
  # Static checks on an Essentials game:
  # - every script section parses with Prism;
  # - every Ruby fragment of an event command parses;
  # - event commands are read from maps, common events and troops.
  #
  # It answers "does the code compile", not "do the called methods exist".
  class Check
    SCRIPT_CODES = [355].freeze

    Report = Struct.new(:scripts, :script_errors, :events, :event_errors, :errors, keyword_init: true)

    def initialize(game_dir, work_dir)
      @game_dir = game_dir
      @work_dir = work_dir
    end

    def run
      project = File.join(@work_dir, "unpacked")
      Project.new(@game_dir).unpack(@game_dir, project)

      report = Report.new(scripts: 0, script_errors: 0, events: 0, event_errors: 0, errors: [])
      check_scripts(File.join(project, "scripts"), report)
      tree = File.join(project, "scripts_tree")
      if Dir.exist?(tree)
        Dir.glob(File.join(tree, "**", "*.rb")).sort.each do |path|
          report.scripts += 1
          source = File.binread(path)
          result = Prism.parse(source)
          next if result.success?

          report.script_errors += 1
          error = result.errors.first
          report.errors << "#{path.sub(tree + "/", "")}:#{error.location.start_line}: #{error.message}"
        end
      end
      check_events(File.join(@game_dir, "Data"), report)
      report
    end

    private

    def check_scripts(scripts_dir, report)
      return unless Dir.exist?(scripts_dir)

      Dir.children(scripts_dir).sort.each do |file|
        path = File.join(scripts_dir, file)
        next unless File.file?(path)

        report.scripts += 1
        source = File.binread(path)
        result = Prism.parse(source)
        next if result.success?

        report.script_errors += 1
        error = result.errors.first
        report.errors << "#{file}:#{error.location.start_line}: #{error.message}"
      end
    end

    def check_events(data_dir, report)
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
        each_event_list(object, {}, name, report)
      end
    end

    def each_event_list(object, visited, name, report, &_block)
      case object
      when Array
        id = object.object_id
        return if visited[id]

        visited[id] = true
        if event_list?(object)
          check_event_list(object, name, report)
        else
          object.each { |child| each_event_list(child, visited, name, report) }
        end
      when Hash
        id = object.object_id
        return if visited[id]

        visited[id] = true
        object.each { |_key, child| each_event_list(child, visited, name, report) }
      when String, Integer, Float, Symbol, TrueClass, FalseClass
        nil
      else
        id = object.object_id
        return if visited[id]

        visited[id] = true
        object.instance_variables.each do |ivar|
          each_event_list(object.instance_variable_get(ivar), visited, name, report)
        end
      end
    end

    def event_list?(array)
      !array.empty? && array[0].class.name == "RPG::EventCommand"
    end

    # The interpreter concatenates consecutive 355/655 commands into one Ruby
    # script (see Interpreter#command_355), so the checker must do the same.
    def check_event_list(list, name, report)
      index = 0
      while index < list.length
        command = list[index]
        code = command.instance_variable_get(:@code)
        parameters = command.instance_variable_get(:@parameters)
        if [355, 655].include?(code)
          source = +""
          while index < list.length
            current = list[index]
            current_code = current.instance_variable_get(:@code)
            break unless [355, 655].include?(current_code)

            current_parameters = current.instance_variable_get(:@parameters)
            source << current_parameters[0].to_s << "\n"
            index += 1
          end
          check_source(source, name, report)
        elsif code == 111 && parameters.is_a?(Array) && parameters[0] == 12
          check_source(parameters[1].to_s, name, report)
          index += 1
        else
          index += 1
        end
      end
    end

    def check_source(source, name, report)
      report.events += 1
      result = Prism.parse(source)
      return if result.success?

      report.event_errors += 1
      error = result.errors.first
      report.errors << "#{name}: line #{error.location.start_line}: #{error.message} (#{source.lines.first.to_s.strip[0, 60]})"
    end

    # Walks any structure that contains RPG::EventCommand objects.
    def each_event_command(object, visited = {}, &block)
      return if object.nil?

      case object
      when Array
        object.each { |child| each_event_command(child, visited, &block) }
      when Hash
        object.each { |key, child| each_event_command(child, visited, &block) }
      when String, Integer, Float, Symbol, TrueClass, FalseClass
        nil
      else
        id = object.object_id
        return if visited[id]

        visited[id] = true
        if object.class.name == "RPG::EventCommand" && object.instance_variable_defined?(:@code) &&
           SCRIPT_CODES.include?(object.instance_variable_get(:@code))
          yield object
        end
        object.instance_variables.each do |ivar|
          each_event_command(object.instance_variable_get(ivar), visited, &block)
        end
      end
    end
  end
end
