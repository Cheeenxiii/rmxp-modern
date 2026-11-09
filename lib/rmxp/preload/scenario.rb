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

    class << self
      attr_reader :frames, :times

      # mkxp-z calls Graphics.update a few times while loading scripts, so the
      # first frames are ignored for timing.
      attr_reader :logic, :render

      # Called just before the real Graphics.update: the gap since the last
      # update returned is the game logic (input, scene update, ...).
      def before_update(now)
        @started_at ||= now
        return if now - @started_at < WARMUP

        unless @running
          @running = true
          @start = now
          @update_end = now
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
        logic = percentile_stats(@logic)
        render = percentile_stats(@render)
        total = percentile_stats(@total)

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
