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
    @times = []
    @last = nil
    @start = nil
    @started_at = nil

    class << self
      attr_reader :frames, :times

      # mkxp-z calls Graphics.update a few times while loading scripts, so the
      # first frames are ignored for timing.
      def tick
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @started_at ||= now
        return if now - @started_at < WARMUP

        unless @running
          @running = true
          @start = now
          @last = now
        end
        @times << (now - @last)
        @last = now
        @frames += 1
        finish if now - @start >= SECONDS
      end

      def finish
        elapsed = @last - @start
        sorted = @times.sort
        median = sorted.empty? ? 0.0 : sorted[sorted.length / 2]
        mean = @times.empty? ? 0.0 : @times.sum / @times.length
        fps = elapsed.positive? ? @frames / elapsed : 0.0

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
        lines << "segments=#{@times.length}"
        lines << "frames=#{@frames}"
        lines << "elapsed=#{format('%.6f', elapsed)}"
        lines << "fps=#{format('%.3f', fps)}"
        lines << "frame_median_ms=#{format('%.4f', median * 1000.0)}"
        lines << "frame_mean_ms=#{format('%.4f', mean * 1000.0)}"
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
    Rmxp::Scenario.tick
    __rmxp_original_update
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
