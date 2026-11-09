#!/usr/bin/env ruby
# Vérifie que le MT19937 maison tire exactement les mêmes nombres que CRuby
# avec la même graine : bits bruts, flottants, entiers et plages.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rmxp/mt19937"

SEEDS = [
  0, 1, 2, 42, 1234, -1, -42, 2**31 - 1, 2**31, 2**32 - 1, 2**32,
  2**32 + 1, 2**63, 10**30, 999_999_999_999_999_999_999_999,
].freeze

# Opérations passées à Kernel#rand / Random#rand.
OPS = [
  [], [100], [1], [2], [6], [10], [1000], [65_536], [2**31 - 1],
  [-100], [-1], [-2], [0], [0.0], [0.5], [1.5], [1.9], [-0.5],
  [1..6], [1...6], [10..20], [-5..5], [0..0], [1.0..6.0], [1.0...6.0],
  [0.5..1.5], [2.0..2.0],
].freeze

def same_number?(expected, actual)
  if expected.is_a?(Float) || actual.is_a?(Float)
    return false unless expected.is_a?(Float) && actual.is_a?(Float)
    return [expected].pack("G") == [actual].pack("G")
  end
  expected == actual
end

def check(name, expected, actual, context)
  return 0 if same_number?(expected, actual)

  puts "ECHEC #{name} #{context}: attendu #{expected.inspect} (#{expected.class}), obtenu #{actual.inspect} (#{actual.class})"
  1
end

failures = 0

# 1. Bits bruts : Random#bytes(4) renvoie genrand_int32 en little-endian.
SEEDS.each do |seed|
  cruby = Random.new(seed)
  ours = Rmxp::MT19937.new(seed)
  20.times do |i|
    expected = cruby.bytes(4).unpack1("V")
    actual = ours.genrand_int32
    failures += check("bits", expected, actual, "graine=#{seed} tirage=#{i}")
  end
end

# 2. Conversions Kernel#rand et Random#rand sur des millions de tirages.
def run_kernel(seed, count)
  srand(seed)
  ours = Rmxp::MT19937.new(seed)
  count.times do |i|
    op = OPS[i % OPS.size]
    expected = rand(*op)
    actual = Rmxp::CRubyRandom.kernel_rand(ours, op)
    return [i, op, expected, actual] unless same_number?(expected, actual)
  end
  nil
end

RANDOM_OPS = OPS.reject do |op|
  next false unless op.length == 1

  arg = op[0]
  (arg.is_a?(Integer) && arg <= 0) || (arg.is_a?(Float) && (arg.negative? || arg.nan?))
end.freeze

# Plages vides ou inversées : Kernel#rand renvoie nil, Random#rand lève.
EMPTY_RANGE_OPS = [[0..-1], [1..0], [0...0], [2.0...2.0], [1.0...1.0]].freeze

def run_random(seed, count)
  cruby = Random.new(seed)
  ours = Rmxp::DeterministicRandom.new(seed)
  count.times do |i|
    op = RANDOM_OPS[i % RANDOM_OPS.size]
    expected = op.empty? ? cruby.rand : cruby.rand(*op)
    actual = op.empty? ? ours.rand : ours.rand(*op)
    return [i, op, expected, actual] unless same_number?(expected, actual)
  end
  nil
end

SEEDS.each do |seed|
  EMPTY_RANGE_OPS.each do |op|
    srand(seed)
    expected = rand(*op)
    actual = Rmxp::CRubyRandom.kernel_rand(Rmxp::MT19937.new(seed), op)
    failures += check("plage vide", expected, actual, "graine=#{seed} Kernel #{op.inspect}")
  end
  [run_kernel(seed, 2_000), run_random(seed, 2_000)].each do |mismatch|
    next unless mismatch

    index, op, expected, actual = mismatch
    puts "ECHEC séquence graine=#{seed} tirage=#{index} op=#{op.inspect}: attendu #{expected.inspect}, obtenu #{actual.inspect}"
    failures += 1
  end
end

# 3. Test long : 2 millions de tirages répartis sur quelques graines.
SEEDS.first(6).each do |seed|
  count = 2_000_000 / 6
  mismatch = run_kernel(seed, count)
  if mismatch
    index, op, expected, actual = mismatch
    puts "ECHEC long graine=#{seed} tirage=#{index} op=#{op.inspect}: attendu #{expected.inspect}, obtenu #{actual.inspect}"
    failures += 1
  end
end

if failures.zero?
  puts "mt19937: ok (bits bruts, Kernel#rand, Random#rand, 2M de tirages)"
  exit 0
else
  puts "mt19937: #{failures} échec(s)"
  exit 1
end
