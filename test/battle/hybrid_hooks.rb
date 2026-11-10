# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Replaces only the final damage formula with the Spinel extension.
module BattleHotDamage
  def pbCalcDamage(user, target, numTargets = 1)
    return if statusMove?

    if target.damageState.disguise || target.damageState.iceFace
      target.damageState.calcDamage = 1
      return
    end
    max_stage = Battle::Battler::STAT_STAGE_MAXIMUM
    stageMul = Battle::Battler::STAT_STAGE_MULTIPLIERS
    stageDiv = Battle::Battler::STAT_STAGE_DIVISORS
    type = @calcType
    target.damageState.critical = pbIsCritical?(user, target)
    baseDmg = pbBaseDamage(@power, user, target)
    atk, atkStage = pbGetAttackStats(user, target)
    if !target.hasActiveAbility?(:UNAWARE) || @battle.moldBreaker
      atkStage = max_stage if target.damageState.critical && atkStage < max_stage
      atk = (atk.to_f * stageMul[atkStage] / stageDiv[atkStage]).floor
    end
    defense, defStage = pbGetDefenseStats(user, target)
    if !user.hasActiveAbility?(:UNAWARE)
      defStage = max_stage if target.damageState.critical && defStage > max_stage
      defense = (defense.to_f * stageMul[defStage] / stageDiv[defStage]).floor
    end
    multipliers = {
      :power_multiplier        => 1.0,
      :attack_multiplier       => 1.0,
      :defense_multiplier      => 1.0,
      :final_damage_multiplier => 1.0
    }
    pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    baseDmg = [(baseDmg * multipliers[:power_multiplier]).round, 1].max
    atk     = [(atk     * multipliers[:attack_multiplier]).round, 1].max
    defense = [(defense * multipliers[:defense_multiplier]).round, 1].max
    target.damageState.calcDamage =
      BattleHot.damage(user.level, baseDmg, atk, defense, multipliers[:final_damage_multiplier])
  end
end
Battle::Move.prepend(BattleHotDamage)
