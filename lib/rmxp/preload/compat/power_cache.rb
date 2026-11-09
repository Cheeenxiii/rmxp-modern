# Cache générique de System.power_state. Les jeux Essentials v19+ appellent
# pbBatteryLow? à chaque frame ; sur certaines plateformes SDL_GetPowerInfo
# coûte ~1 ms par appel. Fenêtre par défaut : 5 s, désactivable avec
# RMXP_POWER_CACHE_SECONDS=0.
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
