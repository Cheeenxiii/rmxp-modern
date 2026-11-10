# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Constantes Input absentes de certains moteurs (Reborn, bindings Switch).
# Shim générique installé par migrate ; aucune dépendance à un jeu précis.
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
