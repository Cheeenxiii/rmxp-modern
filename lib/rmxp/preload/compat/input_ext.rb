# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Input constants used by some games (Reborn, Essentials v16) but not defined
# by mkxp-z, which names the same keys F5/F6/F7. The Switch port binds those
# keys to ZL, ZR and minus, so a game shim is enough and no engine change is
# needed. Generic shim installed by migrate; does not depend on a specific
# game.
module Input
  # real: F5/F6/F7 are the keys behind E/F/D.
  E = F5 unless const_defined?(:E)
  F = F6 unless const_defined?(:F)
  D = F7 unless const_defined?(:D)
end

# Input::Controller.axes_trigger (analog triggers) comes from mkxp-z itself,
# so it is deliberately not provided here: a stub returning zero would hide
# the real implementation on engines that have it.
