# Génère les tables GameData utilisées par les combats sous forme de littéraux
# Ruby (appels à GameData::X.register), pour ne pas dépendre de Marshal au
# runtime du harnais compilé.
$LOAD_PATH.unshift(File.expand_path(__dir__))
require_relative "stubs"
require "zlib"

ROOT = File.expand_path("../..", __dir__)
KIT = ENV["RMXP_KIT"] || File.join(ROOT, "corpus/kits/v21.1/Pokemon Essentials v21.1 2023-07-30")
SCRIPTS = File.join(ROOT, "tmp/battle/scripts")
OUT = ENV["RMXP_DATA"] || File.join(ROOT, "tmp/battle/battle_data.rb")

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
  next if File.basename(path).include?("Main")

  eval(File.binread(path), TOPLEVEL_BINDING, File.basename(path))
end
GameData.load_all

PRIMITIVE = [NilClass, TrueClass, FalseClass, Integer, Float, String, Symbol, Array, Hash].freeze
def primitive?(value)
  return true if PRIMITIVE.include?(value.class)

  value.is_a?(Array) && value.all? { |v| primitive?(v) }
end

def object_hash(obj)
  hash = {}
  obj.instance_variables.each do |ivar|
    key = ivar.to_s.sub("@", "").to_sym
    value = obj.instance_variable_get(ivar)
    raise "valeur non littérale #{obj.class}##{ivar}: #{value.class}" unless primitive?(value)

    hash[key] = value
  end
  hash[:id_number] = obj.id_number if obj.respond_to?(:id_number)
  hash
end

order = %i[Stat GenderRatio GrowthRate Nature Type Ability Target Status BattleWeather
           TerrainTag TrainerType Item Move Species]
wanted = order.to_h { |name| [name, true] }
tables = GameData.constants.filter_map do |name|
  next unless wanted[name]

  klass = GameData.const_get(name)
  next unless klass.is_a?(Class) && klass.const_defined?(:DATA_FILENAME)

  klass
end
by_name = tables.to_h { |klass| [klass.name.split("::").last.to_sym, klass] }
ordered = order.filter_map { |name| by_name[name] }

File.open(OUT, "w") do |file|
  file.puts "# Généré par test/battle/gen_battle_data.rb — ne pas éditer."
  ordered.each do |klass|
    objects = klass::DATA.values.uniq
    file.puts "# #{klass.name} : #{objects.length} entrées"
    objects.each do |obj|
      hash = object_hash(obj)
      file.puts "#{klass.name}.register(#{hash.inspect})"
    end
  end
end
puts "#{OUT} : #{File.size(OUT)} octets, #{ordered.length} tables"
