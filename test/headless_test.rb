#!/usr/bin/env ruby
# Lance un jeu dans mkxp-z sous Xvfb avec le RNG déterministe et un compteur
# de frames, puis écrit un dump d'état. Deux exécutions avec la même graine
# doivent produire le même dump.
#
# usage: test/headless_test.rb JEU DATA_RECONSTRUITE [SECONDES] [SEED]
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "fileutils"
require "json"

game = File.expand_path(ARGV[0] || abort("usage: headless_test.rb JEU DATA [FRAMES] [SEED]"))
rebuilt_data = File.expand_path(ARGV[1] || abort("DATA_RECONSTRUITE manquant"))
seconds = (ARGV[2] || "2.0").to_f
seed = (ARGV[3] || "1").to_i
mkxp = ENV["MKXP_BIN"] || File.expand_path("../vendor/mkxp-z/build/mkxp-z.x86_64", __dir__)

slug = game.sub(Dir.pwd + "/", "").gsub(/[^A-Za-z0-9_.-]+/, "__")
root = File.expand_path("../tmp/headless/#{slug}", __dir__)
game_dir = File.join(root, "game")
dump_path = File.join(root, "dump.txt")
FileUtils.rm_rf(root)
FileUtils.mkdir_p(game_dir)

# Copie les fichiers du jeu (les dossiers d'assets sont liés, Data vient de la
# reconstruction).
Dir.children(game).each do |entry|
  next if entry == "Data"

  source = File.join(game, entry)
  target = File.join(game_dir, entry)
  if Dir.exist?(source)
    File.symlink(source, target)
  else
    FileUtils.cp(source, target)
  end
end
FileUtils.cp_r(rebuilt_data, File.join(game_dir, "Data"))

# Script de preload : le MT19937, le shim et la sonde de scénario.
preload = File.join(game_dir, "headless_preload.rb")
File.write(preload,
           File.read(File.expand_path("../lib/rmxp/mt19937.rb", __dir__)) + "\n" +
           File.read(File.expand_path("../lib/rmxp/preload/deterministic_random.rb", __dir__)))
File.write(preload, File.read(preload) + "\n" + File.read(File.expand_path("../lib/rmxp/preload/scenario.rb", __dir__)))

# mkxp.json : conserve les réglages existants, ajoute le preload.
config_path = File.join(game_dir, "mkxp.json")
config = File.file?(config_path) ? File.read(config_path) : "{\n}\n"
unless config.include?("headless_preload.rb")
  lines = config.lines
  brace = lines.index { |line| line.strip.start_with?("{") } || 0
  lines.insert(brace + 1, "  \"preloadScript\": [\"headless_preload.rb\"],\n")
  config = lines.join
end
File.write(config_path, config)

command = [
  "timeout", "180",
  "xvfb-run", "-a", "-s", "-screen 0 1024x768x24",
  mkxp
]
env = {
  "SRCDIR" => game_dir,
  "RMXP_SEED" => seed.to_s,
  "RMXP_SECONDS" => seconds.to_s,
  "RMXP_DUMP" => dump_path,
  "SDL_AUDIODRIVER" => "dummy",
  "SDL_VIDEODRIVER" => "x11",
}
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
ok = system(env, *command, chdir: game_dir)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
unless ok
  puts "mkxp-z a échoué (code #{$?.exitstatus}) après #{format('%.1f', elapsed)}s"
  exit 1
end
unless File.file?(dump_path)
  puts "pas de dump après #{format('%.1f', elapsed)}s"
  exit 1
end
puts File.read(dump_path)
