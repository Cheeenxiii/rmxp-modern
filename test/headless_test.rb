#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Runs a game in mkxp-z under Xvfb with the deterministic RNG and a frame
# counter, then writes a state dump. Two runs with the same seed must produce
# the same dump.
#
# usage: test/headless_test.rb GAME REBUILT_DATA [SECONDS] [SEED]
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "fileutils"
require "json"

game = File.expand_path(ARGV[0] || abort("usage: headless_test.rb GAME REBUILT_DATA [SECONDS] [SEED]"))
rebuilt_data = File.expand_path(ARGV[1] || abort("missing REBUILT_DATA"))
seconds = (ARGV[2] || "2.0").to_f
seed = (ARGV[3] || "1").to_i
mkxp = ENV["MKXP_BIN"] || File.expand_path("../vendor/mkxp-z/build/mkxp-z.x86_64", __dir__)

slug = game.sub(Dir.pwd + "/", "").gsub(/[^A-Za-z0-9_.-]+/, "__")
root = File.expand_path("../tmp/headless/#{slug}", __dir__)
game_dir = File.join(root, "game")
dump_path = File.join(root, "dump.txt")
FileUtils.rm_rf(root)
FileUtils.mkdir_p(game_dir)

# Copy the game files (asset directories are symlinked, Data comes from the
# rebuild).
Dir.children(game).each do |entry|
  next if entry == "Data"

  source = File.join(game, entry)
  target = File.join(game_dir, entry)
  if Dir.exist?(source)
    FileUtils.cp_r(source, target)
  else
    FileUtils.cp(source, target)
  end
end
FileUtils.cp_r(rebuilt_data, File.join(game_dir, "Data"))

# Preload script: MT19937, the RNG shim and the scenario probe.
preload = File.join(game_dir, "headless_preload.rb")
File.write(preload,
           File.read(File.expand_path("../lib/rmxp/mt19937.rb", __dir__)) + "\n" +
           File.read(File.expand_path("../lib/rmxp/preload/deterministic_random.rb", __dir__)))
File.write(preload, File.read(preload) + "\n" + File.read(File.expand_path("../lib/rmxp/preload/scenario.rb", __dir__)))

# mkxp.json: keep the existing settings, add the preload.
config_path = File.join(game_dir, "mkxp.json")
config = File.file?(config_path) ? File.read(config_path) : "{\n}\n"
unless config.include?("headless_preload.rb")
  lines = config.lines
  brace = lines.index { |line| line.strip.start_with?("{") } || 0
  lines.insert(brace + 1, "  \"preloadScript\": [\"headless_preload.rb\"],\n")
  lines.insert(brace + 1, "  \"fixedFramerate\": -1,\n") if ENV["RMXP_UNCAPPED"]
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
%w[RMXP_JOURNEY RMXP_JOURNEY_MAP RMXP_PROFILE RMXP_WATCHDOG RMXP_WARMUP].each do |key|
  env[key] = ENV[key] if ENV[key]
end
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
ok = system(env, *command, chdir: game_dir)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
unless ok
  puts "mkxp-z failed (code #{$?.exitstatus}) after #{format('%.1f', elapsed)}s"
  exit 1
end
unless File.file?(dump_path)
  puts "no dump after #{format('%.1f', elapsed)}s"
  exit 1
end
puts File.read(dump_path)
