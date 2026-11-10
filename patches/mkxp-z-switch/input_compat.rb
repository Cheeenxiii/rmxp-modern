# Reborn utilise des constantes Input et Controller absentes du binding du port
# Switch. On fournit des touches neutres et un axe déclencheur nul.
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
