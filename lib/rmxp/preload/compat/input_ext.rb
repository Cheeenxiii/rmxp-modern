# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Input constants missing from some engines (Reborn, Switch bindings).
# Generic shim installed by migrate; does not depend on a specific game.
module Input
  E = F5 unless const_defined?(:E)
  F = F6 unless const_defined?(:F)
  D = F7 unless const_defined?(:D)

  module Controller
    def self.axes_trigger
      [0, 0, 0, 0]
    end unless respond_to?(:axes_trigger)
  end
end
