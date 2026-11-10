# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

module BattleHot
  #: (Integer, Integer, Integer, Integer, Float) -> Integer
  def self.damage(level, base, attack, defense, final_multiplier)
    damage = (((2 * level / 5 + 2) * base * attack / defense) / 50) + 2
    damage = (damage * final_multiplier).round
    damage = 1 if damage < 1
    damage
  end
end
