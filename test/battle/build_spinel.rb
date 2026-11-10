# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Assemble un programme unique (stubs + moteur ESS + données littérales +
# harnais) pour la compilation Spinel.
ROOT = File.expand_path("../..", __dir__)
OUT = ENV["RMXP_SPINEL_SRC"] || File.join(ROOT, "tmp/battle/spinel_battle.rb")
SCRIPTS = File.join(ROOT, "tmp/battle/scripts")
DATA = File.join(ROOT, ENV["RMXP_SMALL_DATA"] ? "tmp/battle/battle_data_small.rb" : "tmp/battle/battle_data.rb")
raise "lance d'abord test/battle/gen_battle_data.rb" unless File.file?(DATA)

parts = []
parts << File.read(File.join(__dir__, "stubs.rb"))
parts << File.read(File.join(ROOT, "lib/rmxp/mt19937.rb"))
parts << File.read(File.join(__dir__, "rng_shim_spinel.rb"))
keywords = ENV["RMXP_SCRIPT_KEYWORDS"]
filter = keywords ? Regexp.new(keywords.split(",").map { |k| Regexp.escape(k) }.join("|"), Regexp::IGNORECASE) : nil
list = ENV["RMXP_SCRIPT_LIST"] ? File.read(ENV["RMXP_SCRIPT_LIST"]).split("\n").to_h { |n| [n, true] } : nil
Dir.glob(File.join(SCRIPTS, "*.rb")).sort.each do |path|
  name = File.basename(path)
  next if name.include?("Main")
  next if filter && !name.match?(filter)
  next if list && !list[name]

  parts << File.read(path)
end
parts << File.read(DATA)
parts << File.read(File.join(__dir__, "harness_spinel.rb"))
File.write(OUT, parts.join("\n"))
puts "#{OUT}: #{File.size(OUT)} octets"
