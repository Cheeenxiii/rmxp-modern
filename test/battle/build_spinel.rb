# Assemble un programme unique (stubs + moteur ESS + données littérales +
# harnais) pour la compilation Spinel.
ROOT = File.expand_path("../..", __dir__)
OUT = ENV["RMXP_SPINEL_SRC"] || File.join(ROOT, "tmp/battle/spinel_battle.rb")
SCRIPTS = File.join(ROOT, "tmp/battle/scripts")
DATA = File.join(ROOT, "tmp/battle/battle_data.rb")
raise "lance d'abord test/battle/gen_battle_data.rb" unless File.file?(DATA)

parts = []
parts << File.read(File.join(__dir__, "stubs.rb"))
parts << File.read(File.join(ROOT, "lib/rmxp/mt19937.rb"))
parts << File.read(File.join(__dir__, "rng_shim_spinel.rb"))
keywords = ENV["RMXP_SCRIPT_KEYWORDS"]
filter = keywords ? Regexp.new(keywords.split(",").map { |k| Regexp.escape(k) }.join("|"), Regexp::IGNORECASE) : nil
Dir.glob(File.join(SCRIPTS, "*.rb")).sort.each do |path|
  next if File.basename(path).include?("Main")
  next if filter && !File.basename(path).match?(filter)

  parts << File.read(path)
end
parts << File.read(DATA)
parts << File.read(File.join(__dir__, "harness_spinel.rb"))
File.write(OUT, parts.join("\n"))
puts "#{OUT}: #{File.size(OUT)} octets"
