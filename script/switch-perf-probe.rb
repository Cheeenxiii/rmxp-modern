# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT
#
# Test-only calibration probe. Every few seconds it prints:
#   frames=        frames in the window -> fps = frames / 5 s
#   avg=           wall time inside Graphics#update, *including* engine waits
#                  and vsync, so it is not a work measure
#   cpu=           process CPU time per frame over the window (all threads and
#                  all work, including drawing outside Graphics#update), the
#                  work measure to compare PC and Switch. The Switch Ruby has
#                  no process CPU clock (libnx has no clock_gettime for it), so
#                  there the field is `na` and only fps/avg are meaningful.
#   worst=         worst wall time inside Graphics#update
#   scene=, map=   what was running
# Added to console test builds only (script/switch-build --perf-probe).

module RmxpPerf
  INTERVAL = 5.0
  @frames = 0
  @sum = 0.0
  @worst = 0.0
  # aarch64-elf (the Switch port) has no process CPU clock: querying it is a
  # fatal [BUG] in Ruby, not a rescuable exception.
  CPU_CLOCK = (RUBY_PLATFORM =~ /linux|darwin|mingw|mswin/ ? Process::CLOCK_PROCESS_CPUTIME_ID : nil)
  @last_cpu = CPU_CLOCK ? Process.clock_gettime(CPU_CLOCK) : nil
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
      cpu = if CPU_CLOCK
              cpu_now = Process.clock_gettime(CPU_CLOCK)
              value = (cpu_now - @last_cpu) * 1000.0 / @frames
              @last_cpu = cpu_now
              format("%.2f", value)
            else
              "na"
            end
      puts format("RMXP_PERF frames=%d fps=%.1f avg=%.2fms cpu=%s worst=%.2fms scene=%s map=%s",
                  @frames, @frames / (now - @last), @sum * 1000.0 / @frames,
                  cpu, @worst * 1000.0, scene, map)
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
