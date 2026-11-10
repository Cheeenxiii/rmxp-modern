# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# real: caches System.power_state. Essentials v19+ calls pbBatteryLow? every
# frame, and on some platforms SDL_GetPowerInfo costs about 1 ms per call.
# The value is refreshed every 5 seconds by default; set
# RMXP_POWER_CACHE_SECONDS=0 to disable the cache.
module System
  class << self
    alias __rmxp_original_power_state power_state unless method_defined?(:__rmxp_original_power_state)

    def power_state
      interval = (ENV["RMXP_POWER_CACHE_SECONDS"] || "5").to_f
      return __rmxp_original_power_state if interval <= 0

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if !defined?(@__rmxp_power_state_at) || @__rmxp_power_state_at.nil? ||
         now - @__rmxp_power_state_at >= interval
        @__rmxp_power_state = __rmxp_original_power_state
        @__rmxp_power_state_at = now
      end
      @__rmxp_power_state
    end
  end
end
