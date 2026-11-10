# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT
#
# Test-only calibration probe: prints the time spent inside Graphics#update
# (Ruby logic plus the frame's work) every few seconds, to stdout, which on
# the Switch lands in mkxp-z.log. Added to console test builds only.

module RmxpPerf
  INTERVAL = 5.0
  @frames = 0
  @sum = 0.0
  @worst = 0.0
  @last = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  class << self
    def sample(seconds)
      @sum += seconds
      @worst = seconds if seconds > @worst
      @frames += 1
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if now - @last < INTERVAL

      scene = begin
        $scene.class.to_s
      rescue StandardError
        "-"
      end
      map = begin
        (defined?($game_map) && $game_map) ? $game_map.map_id : "-"
      rescue StandardError
        "-"
      end
      puts format("RMXP_PERF frames=%d avg=%.2fms worst=%.2fms scene=%s map=%s",
                  @frames, @sum * 1000.0 / @frames, @worst * 1000.0, scene, map)
      $stdout.flush if $stdout.respond_to?(:flush)
      @frames = 0
      @sum = 0.0
      @worst = 0.0
      @last = now
    end
  end
end

class << Graphics
  alias_method :__rmxp_perf_update, :update unless method_defined?(:__rmxp_perf_update)
  def update
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    __rmxp_perf_update
    RmxpPerf.sample(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
  end
end
