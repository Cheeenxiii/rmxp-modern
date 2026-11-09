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

GameData.load_all
$game_switches = Array.new(2000, false)
$game_variables = Array.new(2000, 0)
$game_temp = Game_Temp.new
$game_system = Game_System.new
$PokemonSystem = PokemonSystem.new
$player = Player.new("PLAYER", GameData::TrainerType.keys.first)
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
species_pool = GameData::Species.keys
type_pool = GameData::TrainerType.keys

N.times do |i|
  $battle_lines = []
  $turn = 0
  p1 = Pokemon.new(species_pool[rand(species_pool.length)], 30 + rand(31))
  p2 = Pokemon.new(species_pool[rand(species_pool.length)], 30 + rand(31))
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
