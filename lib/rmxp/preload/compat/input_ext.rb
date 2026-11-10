# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Extensions of the Reborn mkxp-z fork that some games call but stock mkxp-z
# does not provide. Generic shims installed by migrate; they do not depend on a
# specific game. Guarded so the fork's own implementations always win.

# Input constants used by some games (Reborn, Essentials v16) but not defined
# by mkxp-z, which names the same keys F5/F6/F7. The Switch port binds those
# keys to ZL, ZR and minus, so a game shim is enough and no engine change is
# needed.
module Input
  # real: F5/F6/F7 are the keys behind E/F/D.
  E = F5 unless const_defined?(:E)
  F = F6 unless const_defined?(:F)
  D = F7 unless const_defined?(:D)
end

# Audio.se_play_position is the Reborn fork's positional variant of
# Audio.se_play(name, volume = 100, pitch = 100): same arguments plus x, y, z
# (a mono sound's position in the scene). Stock mkxp-z mixes all SE centred, so
# the position is dropped and the sound is played normally; only the stereo
# panning is lost, which vanilla Essentials never had either. The return value
# is Audio.se_play's.
if defined?(Audio) && !Audio.respond_to?(:se_play_position)
  def Audio.se_play_position(name, volume = 100, pitch = 100, _x = 0, _y = 0, _z = 0)
    se_play(name, volume, pitch)
  end
end

# Input::Controller.axes_trigger (analog triggers) comes from mkxp-z itself,
# so it is deliberately not provided here: a stub returning zero would hide
# the real implementation on engines that have it.

# TilemapUtils.updateAutoTiles is another Reborn-fork extension: its Scene_Map
# calls it once per frame to animate autotiles. Stock mkxp-z animates the
# tilemap itself, so the call is a no-op here; without this method New Game
# raises NameError.
unless defined?(TilemapUtils)
  module TilemapUtils
    def self.updateAutoTiles(*)
      nil
    end
  end
end
