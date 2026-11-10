# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

$LOAD_PATH.unshift(File.expand_path(__dir__))
require_relative "stubs"
require_relative "../../lib/rmxp/mt19937"
require_relative "../../lib/rmxp/preload/deterministic_random"
require "zlib"

N = (ENV["RMXP_BATTLES"] || "20").to_i
SEED = (ENV["RMXP_SEED"] || "1").to_i
LOG_PATH = ENV["RMXP_LOG"] || File.join(__dir__, "battle_log.txt")

ROOT = File.expand_path("../..", __dir__)
KIT = ENV["RMXP_KIT"] || File.join(ROOT, "corpus/kits/v21.1/Pokemon Essentials v21.1 2023-07-30")
SCRIPTS = File.join(ROOT, "tmp/battle/scripts")

unless Dir.exist?(SCRIPTS)
  Dir.mkdir(File.dirname(SCRIPTS)) unless Dir.exist?(File.dirname(SCRIPTS))
  Dir.mkdir(SCRIPTS)
  data = Marshal.load(File.binread(File.join(KIT, "Data/Scripts.rxdata")))
  data.each_with_index do |(id, name, compressed), index|
    safe = name.dup.force_encoding(Encoding::UTF_8).scrub("_").gsub(/[^A-Za-z0-9_.\- ]/, "_").strip
    File.binwrite(format("%s/%03d_%s.rb", SCRIPTS, index + 1, safe), Zlib::Inflate.inflate(compressed))
  end
end

Dir.chdir(KIT)
Dir.glob(File.join(SCRIPTS, "*.rb")).sort.each do |path|
  name = File.basename(path)
  next if name.include?("Main")

  eval(File.binread(path), TOPLEVEL_BINDING, name)
end

if ENV["RMXP_USE_LITERAL_DATA"]
  load(File.join(ROOT, ENV["RMXP_SMALL_DATA"] ? "tmp/battle/battle_data_small.rb" : "tmp/battle/battle_data.rb"))
else
  GameData.load_all
end

if ENV["RMXP_HYBRID_SO"]
  require File.expand_path(ENV["RMXP_HYBRID_SO"])
  load File.join(__dir__, "hybrid_hooks.rb")
end
$game_switches = Array.new(2000, false)
$game_variables = Array.new(2000, 0)
$game_temp = Game_Temp.new
$game_system = Game_System.new
$PokemonSystem = PokemonSystem.new
class RmxpFakeOwner
  attr_reader :name
  def initialize
    @name = "PLAYER"
    @public_id = 0
  end
  def public_id; 0; end
  def language; 2; end
  def pokedex; @pokedex ||= RmxpFakePokedex.new; end
  def secret_ID; 0; end
  def party; []; end
  def money; 0; end
  def badges; []; end
  def badge_count; 0; end
  def has_pokedex?; true; end
end

class RmxpFakePokedex
  def register(_pkmn); end
  def seen?(*_a); true; end
  def owned?(*_a); true; end
  def seen_form?(*_a); true; end
  def owned_form?(*_a); true; end
end
$player = RmxpFakeOwner.new
$game_map = Object.new
class << $game_map
  def metadata; nil; end
  def map_id; 1; end
  def name; "Test Map"; end
end
$game_player = Object.new
class << $game_player
  def terrain_tag; ::RmxpTerrainTagStub::TAG; end
  def pbFacingTerrainTag; ::RmxpTerrainTagStub::TAG; end
end
module RmxpTerrainTagStub
  TAG = Object.new
  def TAG.battle_environment; :None; end
end

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
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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

N.times do |i|
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
  case result
  when 1 then wins += 1
  when 2 then losses += 1
  else draws += 1
  end
  lines << "### Combat #{i + 1} : #{p1.species} vs #{p2.species} -> #{result}"
  lines.concat($battle_lines)
end
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
File.write(LOG_PATH, lines.join("\n") + "\n")
puts "combats=#{N} seed=#{SEED} gagnés=#{wins} perdus=#{losses} nuls=#{draws} " \
     "temps=#{format('%.3f', elapsed)}s lignes=#{lines.length}"
puts "log: #{LOG_PATH}"
