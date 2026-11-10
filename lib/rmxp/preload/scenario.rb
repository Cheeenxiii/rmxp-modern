# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Headless scenario probe for mkxp-z.
#
# Loaded as a preload script. Essentials later aliases Graphics.update into
# update_KGC_SpecialTransition and redefines Graphics.update; our wrapper is
# what its alias captures, and it calls the original C method, so there is no
# recursion.
#
# Environment:
#   RMXP_SECONDS duration of the measurement window (default 2.0)
#   RMXP_DUMP    dump file path (default scenario_dump.txt)
#   RMXP_SEED    RNG seed, read by deterministic_random.rb

# Profil optionnel (RMXP_PROFILE=1) : self-time et allocations par méthode du
# jeu, via TracePoint. Actif seulement pendant la fenêtre de mesure.
module Rmxp
  module Profile
    @entries = []
    @self_time = Hash.new(0.0)
    @self_alloc = Hash.new(0)
    @calls = Hash.new(0)
    @enabled = false

    class << self
      def start
        return if @enabled

        @enabled = true
        scene_filter = ENV["RMXP_PROFILE_SCENE"]
        @tp = TracePoint.new(:call, :return) do |tp|
          if scene_filter == "battle"
            next unless $rmxp_in_battle
          elsif scene_filter == "map"
            next unless defined?($scene) && $scene.is_a?(Scene_Map) && !$rmxp_in_battle
          end
          path = tp.path.to_s
          next if path.include?("stdlib") || path.include?("<internal:") ||
                  path.include?("headless_preload")

          key = "#{tp.defined_class}##{tp.method_id}"
          if tp.event == :call
            @entries << [key, Process.clock_gettime(Process::CLOCK_MONOTONIC),
                         GC.stat[:total_allocated_objects], 0.0, 0]
            @calls[key] += 1
          else
            entry = @entries.pop
            next if entry.nil?

            total_t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - entry[1]
            total_a = GC.stat[:total_allocated_objects] - entry[2]
            @self_time[entry[0]] += total_t - entry[3]
            @self_alloc[entry[0]] += total_a - entry[4]
            parent = @entries[-1]
            if parent
              parent[3] += total_t
              parent[4] += total_a
            end
          end
        end
        @tp.enable
      end

      def stop
        return unless @enabled

        @tp.disable
        @enabled = false
      end

      def dump(path)
        stop
        by_time = @self_time.sort_by { |_key, value| -value }.first(20)
        by_alloc = @self_alloc.sort_by { |_key, value| -value }.first(15)
        lines = []
        lines << "top self-time (ms, appels):"
        by_time.each do |key, seconds|
          lines << format("  %9.3f ms %7d  %s", seconds * 1000.0, @calls[key], key)
        end
        lines << "top allocations (objets):"
        by_alloc.each do |key, count|
          lines << format("  %9d objs %7d appels  %s", count, @calls[key], key)
        end
        File.write(path, lines.join("\n") + "\n")
        lines
      end
    end
  end
end


module Rmxp
  # Scénario « vraie scène » : démarre une partie, marche sur la carte ou
  # déclenche des combats automatiques, puis mesure la scène ciblée.
  module Journey
    TARGET = (ENV["RMXP_JOURNEY"] || "").to_sym
    MAP_ID = (ENV["RMXP_JOURNEY_MAP"] || "0").to_i

    @installed = false
    @started = false
    @map_frames = 0
    @battling = false

    class << self
      def target
        (TARGET == :map || TARGET == :battle) ? TARGET : nil
      end

      def install
        return unless target
        return if @installed
        return unless defined?(Scene_Intro) && defined?(Scene_Map) && defined?(Battle) &&
                      Battle.const_defined?(:Scene)

        Scene_Intro.prepend(IntroHook)
        Scene_Map.prepend(MapHook)
        Battle::Scene.prepend(BattleHook)
        install_input
        @installed = true
      end

      def install_input
        return if Input.singleton_class.method_defined?(:__rmxp_dir4)

        class << Input
          alias_method :__rmxp_dir4, :dir4
          def dir4
            $rmxp_journey_dir || __rmxp_dir4
          end
          alias_method :__rmxp_trigger, :trigger?
          def trigger?(key)
            return true if (key == Input::USE || key == Input::ACTION) && $rmxp_advance
            __rmxp_trigger(key)
          end
        end
      end

      def trace(msg)
        File.open("journey_trace.txt", "a") { |f| f.puts "#{Process.clock_gettime(Process::CLOCK_MONOTONIC).round(3)} #{msg}" } rescue nil
      end

      def start_game
        return if @started

        trace("start_game")
        @started = true
        Game.start_new
        pkmn = Pokemon.new(:PIKACHU, 50)
        $player.party = [pkmn] if $player.respond_to?(:party=)
        $rmxp_journey_dir = nil
        Thread.new do
          sleep 5
          File.write("stuck_trace.txt", (Thread.main.backtrace || []).join("\n")) rescue nil
        end
      rescue Exception
        @started = false
        raise
      end

      def on_map_update
        return unless @started

        @map_frames += 1
        trace("map_update #{@map_frames}") if @map_frames <= 3
        if target == :battle
          $rmxp_journey_dir = nil
          return if @battling || @map_frames <= 5

          @battling = true
          trace("battle_start map_frames=#{@map_frames}")
          begin
            $player.party.each { |p| p.heal } if $player.respond_to?(:party)
            WildBattle.start(:RATTATA, 50)
          rescue Exception => e
            $rmxp_journey_error = "#{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}"
            File.write("journey_error.txt", $rmxp_journey_error) rescue nil
          ensure
            trace("battle_end")
            @battling = false
            @map_frames = 0
          end
        else
          $rmxp_journey_dir = [2, 6, 8, 4][(@map_frames / 40) % 4]
        end
      end

      def tick(now)
        return unless @started && Rmxp::Scenario.target_scene?

        @advance_tick = (@advance_tick || 0) + 1
        $rmxp_advance = (@advance_tick % 8 == 0)
        active = if target == :map
                   $scene.is_a?(Scene_Map)
                 else
                   $rmxp_in_battle == true
                 end
        if active
          trace("active first") unless @target_since
          @target_since ||= now
          if !Rmxp::Scenario.measuring? && now - @target_since >= Rmxp::Scenario::WARMUP
            trace("measure_start")
            Rmxp::Scenario.start_measurement(now)
          end
        elsif !Rmxp::Scenario.measuring?
          @target_since = nil
        end
      end
    end

    module IntroHook
      def main
        if Rmxp::Journey.target
          Rmxp::Journey.start_game
        else
          super
        end
      end
    end

    module MapHook
      def update
        Rmxp::Journey.trace("hook_update")
        Rmxp::Journey.on_map_update
        super
      end
    end

    module BattleHook
      def pbStartBattle(battle)
        Rmxp::Journey.trace("battle_hook_in")
        $rmxp_in_battle = true
        battle.controlPlayer = true
        super
        Rmxp::Journey.trace("battle_hook_out")
      ensure
        $rmxp_in_battle = false
      end
    end
  end
end

module Rmxp
  module Scenario
    SECONDS = (ENV["RMXP_SECONDS"] || "2.0").to_f
    WARMUP = (ENV["RMXP_WARMUP"] || "1.5").to_f
    DUMP_PATH = ENV["RMXP_DUMP"] || "scenario_dump.txt"

    @frames = 0
    @logic = []
    @render = []
    @total = []
    @gc_time = []
    @gc_count = 0
    @update_end = nil
    @start = nil
    @started_at = nil
    @scene_names = []


    class << self
      attr_reader :frames, :times

      # mkxp-z calls Graphics.update a few times while loading scripts, so the
      # first frames are ignored for timing.
      attr_reader :logic, :render

      # Called just before the real Graphics.update: the gap since the last
      # update returned is the game logic (input, scene update, ...).
      def target_scene?
        Rmxp::Journey.target ? true : false
      end

      def measuring?
        @running == true
      end

      def start_measurement(now)
        return if @running

        @running = true
        @start = now
        @update_end = now
        Rmxp::Profile.start if ENV["RMXP_PROFILE"]
      end

      def before_update(now)
        if Rmxp::Journey.target
          Rmxp::Journey.install
          Rmxp::Journey.tick(now)
          return unless @running
        else
          @started_at ||= now
          return if now - @started_at < WARMUP
          start_measurement(now) unless @running
        end
        @logic << (now - @update_end) if @update_end
        @update_begin = now
      end

      # Called just after it: this is the render work. With the FPS limiter
      # disabled (fixedFramerate = -1) it contains no frame-rate wait.
      def after_update(now)
        return unless @running

        render_time = now - @update_begin
        @render << render_time
        @total << render_time + (@logic.last || 0.0)
        @scene_names << ($rmxp_in_battle ? "Battle::Scene" : ($scene.class.name rescue nil))
        @update_end = now
        if defined?(GC)
          stat = GC.stat
          if @gc_last
            @gc_count += stat[:count] - @gc_last[:count]
            @gc_time << (stat[:time] - @gc_last[:time]) / 1000.0 if stat[:time] && @gc_last[:time]
          end
          @gc_last = stat
        end
        @frames += 1
        finish if now - @start >= SECONDS
      end

      def percentile_stats(values)
        return { p50: 0.0, p95: 0.0, p99: 0.0 } if values.empty?

        sorted = values.sort
        {
          p50: sorted[(sorted.length * 0.50).floor.clamp(0, sorted.length - 1)],
          p95: sorted[(sorted.length * 0.95).floor.clamp(0, sorted.length - 1)],
          p99: sorted[(sorted.length * 0.99).floor.clamp(0, sorted.length - 1)],
        }
      end

      def finish
        elapsed = @update_end - @start
        fps = elapsed.positive? ? @frames / elapsed : 0.0
        keep = if Rmxp::Journey.target == :battle
                 @scene_names.each_index.select { |i| @scene_names[i].to_s.include?("Battle::Scene") }
               elsif Rmxp::Journey.target == :map
                 @scene_names.each_index.select { |i| @scene_names[i].to_s == "Scene_Map" }
               else
                 (0...@logic.length).to_a
               end
        logic = percentile_stats(keep.map { |i| @logic[i] })
        render = percentile_stats(keep.map { |i| @render[i] })
        total = percentile_stats(keep.map { |i| @total[i] })
        target_frames = keep.length

        scene = if defined?($scene) && $scene
                  $scene.class.name
                elsif defined?(SceneManager) && SceneManager.respond_to?(:scene)
                  SceneManager.scene.class.name
                end
        map_id = ($game_map.map_id if defined?($game_map) && $game_map)
        player = ($game_player if defined?($game_player) && $game_player)
        x = (player.x if player)
        y = (player.y if player)

        rng = Rmxp::Deterministic
        draws = []
        20.times { draws << rng.rand(1_000_000) }

        lines = []
        lines << "graphics_frame_count=#{Graphics.frame_count rescue nil}"
        lines << "frames=#{@frames}"
        lines << "target_frames=#{target_frames}"
        lines << "journey_error=#{$rmxp_journey_error}" if defined?($rmxp_journey_error) && $rmxp_journey_error
        lines << "elapsed=#{format('%.6f', elapsed)}"
        lines << "fps=#{format('%.3f', fps)}"
        lines << "logic_p50_ms=#{format('%.4f', logic[:p50] * 1000.0)}"
        lines << "logic_p95_ms=#{format('%.4f', logic[:p95] * 1000.0)}"
        lines << "logic_p99_ms=#{format('%.4f', logic[:p99] * 1000.0)}"
        lines << "render_p50_ms=#{format('%.4f', render[:p50] * 1000.0)}"
        lines << "render_p95_ms=#{format('%.4f', render[:p95] * 1000.0)}"
        lines << "render_p99_ms=#{format('%.4f', render[:p99] * 1000.0)}"
        lines << "total_p50_ms=#{format('%.4f', total[:p50] * 1000.0)}"
        lines << "total_p95_ms=#{format('%.4f', total[:p95] * 1000.0)}"
        lines << "total_p99_ms=#{format('%.4f', total[:p99] * 1000.0)}"
        lines << "gc_count=#{@gc_count}"
        lines << "gc_time_ms=#{format('%.2f', @gc_time.sum * 1000.0)}"
        lines << "scene=#{scene}"
        lines << "map_id=#{map_id}"
        lines << "player_x=#{x}"
        lines << "player_y=#{y}"
        lines << "rng_seed=#{ENV['RMXP_SEED']}"
        lines << "rng_draws=#{draws.join(',')}"
        if ENV["RMXP_PROFILE"]
          File.write(DUMP_PATH + ".profile", Rmxp::Profile.dump(DUMP_PATH + ".profile").join("\n") + "\n")
        end
        File.write(DUMP_PATH, lines.join("\n") + "\n")
        Kernel.exit!(0)
      end
    end
  end
end

class << Graphics
  alias_method :__rmxp_original_update, :update

  def update
    Rmxp::Scenario.before_update(Process.clock_gettime(Process::CLOCK_MONOTONIC))
    __rmxp_original_update
    Rmxp::Scenario.after_update(Process.clock_gettime(Process::CLOCK_MONOTONIC))
  end
end

# Watchdog: dump even if the game never reaches the frame hook.
Thread.new do
  sleep((ENV["RMXP_WATCHDOG"] || "6").to_f)
  begin
    Rmxp::Scenario.finish
  rescue Exception
    Kernel.exit!(1)
  end
end if ENV["RMXP_WATCHDOG"]
