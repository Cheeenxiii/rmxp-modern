# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# ==== harnais de combat (partie compilée) ====
N = (ARGV[0] || "1000").to_i
LOG_PATH = ARGV[2] || "battle_log.txt"

$game_switches = Array.new(2000, false)
$game_variables = Array.new(2000, 0)
$game_temp = Game_Temp.new
$game_system = Game_System.new
$PokemonSystem = PokemonSystem.new

class RmxpFakePokedex
  def register(_pkmn); end
  def seen?(*_a); true; end
  def owned?(*_a); true; end
  def seen_form?(*_a); true; end
  def owned_form?(*_a); true; end
end

class RmxpFakeOwner
  attr_reader :name
  def initialize
    @name = "PLAYER"
    @public_id = 0
    @pokedex = RmxpFakePokedex.new
  end
  def public_id; 0; end
  def language; 2; end
  def pokedex; @pokedex; end
  def secret_ID; 0; end
  def party; []; end
  def money; 0; end
  def badges; []; end
  def badge_count; 0; end
  def has_pokedex?; true; end
end

class RmxpFakeTerrainTag
  def battle_environment; :None; end
end

class RmxpFakeGameMap
  def metadata; nil; end
  def map_id; 1; end
  def name; "Test Map"; end
end

class RmxpFakeGamePlayer
  def terrain_tag; $game_terrain_tag; end
  def pbFacingTerrainTag; $game_terrain_tag; end
end

$game_terrain_tag = RmxpFakeTerrainTag.new
$game_map = RmxpFakeGameMap.new
$game_player = RmxpFakeGamePlayer.new
$player = RmxpFakeOwner.new

module RmxpBattleHooks
  def pbReduceHP(amount, anim = true, registerDamage = true, anyAnim = true)
    before = hp
    result = super
    $battle_lines << "#{name}: -#{before - hp} PV (#{hp}/#{totalhp})" if before != hp
    result
  end
end
Battle::Battler.prepend(RmxpBattleHooks)

module RmxpTurnHooks
  def pbAttackPhase
    $turn += 1
    $battle_lines << "== Tour #{$turn} =="
    super
  end
end
Battle.prepend(RmxpTurnHooks)

$battle_lines = []
lines = []
wins = losses = draws = 0
SMALL_SPECIES = %i[PIKACHU CHARMANDER BULBASAUR SQUIRTLE EEVEE GENGAR MACHAMP ALAKAZAM SNORLAX LAPRAS].freeze
SMALL_MOVES = %i[TACKLE SCRATCH GROWL TAIL_WHIP QUICK_ATTACK THUNDERSHOCK THUNDERBOLT EMBER
                 FLAMETHROWER WATER_GUN SURF VINE_WHIP RAZOR_LEAF CONFUSION PSYCHIC SHADOW_BALL
                 SLUDGE_BOMB BODY_SLAM EARTHQUAKE ICE_BEAM HYPNOSIS AGILITY SWORDS_DANCE RECOVER
                 PROTECT TOXIC LIGHT_SCREEN REFLECT DOUBLE_TEAM REST SLEEP_TALK STRUGGLE].freeze
small = ENV["RMXP_SMALL_DATA"]
species_pool = small ? SMALL_SPECIES.select { |sp| GameData::Species.exists?(sp) } : GameData::Species.keys
move_pool = small ? SMALL_MOVES.select { |mv| GameData::Move.exists?(mv) } : nil
type_pool = GameData::TrainerType.keys

i = 0
while i < N
  $battle_lines = []
  $turn = 0
  p1 = Pokemon.new(species_pool[rand(species_pool.length)], 30 + rand(31), $player, !small)
  p2 = Pokemon.new(species_pool[rand(species_pool.length)], 30 + rand(31), $player, !small)
  if small
    p1.moves = move_pool.sample(4).map { |m| Pokemon::Move.new(m) }
    p2.moves = move_pool.sample(4).map { |m| Pokemon::Move.new(m) }
  end
  t1 = NPCTrainer.new("ASH", type_pool[rand(type_pool.length)])
  t2 = NPCTrainer.new("GARY", type_pool[rand(type_pool.length)])
  t1.party.push(p1)
  t2.party.push(p2)
  scene = Battle::DebugSceneNoVisuals.new(true)
  battle = Battle.new(scene, [p1], [p2], t1, t2)
  battle.debug = true
  battle.controlPlayer = true
  battle.internalBattle = false
  result = battle.pbStartBattle
  wins += 1 if result == 1
  losses += 1 if result == 2
  draws += 1 if result != 1 && result != 2
  lines << "### Combat #{i + 1} : #{p1.species} vs #{p2.species} -> #{result}"
  lines.concat($battle_lines)
  i += 1
end
File.write(LOG_PATH, lines.join("\n") + "\n")
puts "combats=#{N} gagnés=#{wins} perdus=#{losses} nuls=#{draws} lignes=#{lines.length}"
