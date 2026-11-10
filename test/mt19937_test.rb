#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Checks that our MT19937 draws exactly the same numbers as CRuby with the
# same seed: raw bits, floats, integers and ranges.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rmxp/mt19937"

SEEDS = [
  0, 1, 2, 42, 1234, -1, -42, 2**31 - 1, 2**31, 2**32 - 1, 2**32,
  2**32 + 1, 2**63, 10**30, 999_999_999_999_999_999_999_999,
].freeze

# Operations passed to Kernel#rand / Random#rand.
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

  puts "FAIL #{name} #{context}: expected #{expected.inspect} (#{expected.class}), got #{actual.inspect} (#{actual.class})"
  1
end

failures = 0

# 1. Raw bits: Random#bytes(4) returns genrand_int32 in little-endian order.
SEEDS.each do |seed|
  cruby = Random.new(seed)
  ours = Rmxp::MT19937.new(seed)
  20.times do |i|
    expected = cruby.bytes(4).unpack1("V")
    actual = ours.genrand_int32
    failures += check("bits", expected, actual, "seed=#{seed} draw=#{i}")
  end
end

# 2. Kernel#rand and Random#rand conversions over millions of draws.
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

# Empty or reversed ranges: Kernel#rand returns nil, Random#rand raises.
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
    failures += check("empty range", expected, actual, "seed=#{seed} Kernel #{op.inspect}")
  end
  [run_kernel(seed, 2_000), run_random(seed, 2_000)].each do |mismatch|
    next unless mismatch

    index, op, expected, actual = mismatch
    puts "FAIL sequence seed=#{seed} draw=#{index} op=#{op.inspect}: expected #{expected.inspect}, got #{actual.inspect}"
    failures += 1
  end
end

# 3. Long run: 2 million draws spread over a few seeds.
SEEDS.first(6).each do |seed|
  count = 2_000_000 / 6
  mismatch = run_kernel(seed, count)
  if mismatch
    index, op, expected, actual = mismatch
    puts "FAIL long seed=#{seed} draw=#{index} op=#{op.inspect}: expected #{expected.inspect}, got #{actual.inspect}"
    failures += 1
  end
end

if failures.zero?
  puts "mt19937: ok (raw bits, Kernel#rand, Random#rand, 2M draws)"
  exit 0
else
  puts "mt19937: #{failures} failure(s)"
  exit 1
end
