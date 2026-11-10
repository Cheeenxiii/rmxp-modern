# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Input constants missing from some engines (Reborn, Switch bindings).
# Generic shim installed by migrate; does not depend on a specific game.
module Input
  # real: the F5/F6/F7 keys are what the games call E/F/D; the engine binds
  # them to ZL/ZR/minus on Switch.
  E = F5 unless const_defined?(:E)
  F = F6 unless const_defined?(:F)
  D = F7 unless const_defined?(:D)

  module Controller
    # disabled: there is no analog trigger here, so the value is always zero;
    # trigger-based turbo is lost (the E/F/D keys above still reach the game).
    def self.axes_trigger
      [0, 0, 0, 0]
    end unless respond_to?(:axes_trigger)
  end
end
