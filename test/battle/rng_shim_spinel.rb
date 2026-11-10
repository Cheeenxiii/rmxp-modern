# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Spinel-compatible RNG shim: same MT19937 and same conversions as CRuby.
module Rmxp
  module Det
    SEED = (ARGV[1] || "1").to_i
    @global = MT19937.new(SEED)
    class << self
      def rand(*args); CRubyRandom.kernel_rand(@global, args); end
      def srand(seed = nil)
        old = @seed || SEED
        @seed = seed.nil? ? SEED : seed.to_i
        @global = MT19937.new(@seed)
        old
      end
      def random_rand(*args); CRubyRandom.random_rand(@global, args); end
      def random_new(seed = nil); DeterministicRandom.new(seed.nil? ? SEED : seed.to_i); end
      def rand_int(limit); @global.limited_rand(limit); end
    end
  end
end

module Kernel
  def rand(*args); Rmxp::Det.rand(*args); end
  def srand(seed = nil); Rmxp::Det.srand(seed); end
end

class << Kernel
  def rand(*args); Rmxp::Det.rand(*args); end
  def srand(seed = nil); Rmxp::Det.srand(seed); end
end

class Random
  class << self
    def rand(*args); Rmxp::Det.random_rand(*args); end
    def srand(seed = nil); Rmxp::Det.srand(seed); end
    def new(seed = nil); Rmxp::Det.random_new(seed); end
    def new_seed; Rmxp::Det::SEED; end
  end
end

class Array
  def sample(n = :none)
    length = self.length
    if n == :none
      return nil if length == 0
      return self[0] if length < 2
      return self[Rmxp::Det.rand_int(length - 1)]
    end
    n = n.to_int
    return [] if n <= 0
    n = length if n > length
    picks = []
    i = 0
    while i < n
      picks << Rmxp::Det.rand_int(length - i - 1)
      i += 1
    end
    sorted = []
    picks.each do |pick|
      k = pick
      j = 0
      while j < sorted.length
        break if k < sorted[j]
        k += 1
        j += 1
      end
      sorted.insert(j, k)
    end
    sorted.map { |index| self[index] }
  end

  def shuffle
    result = dup
    i = result.length
    while i > 0
      j = Rmxp::Det.rand_int(i - 1)
      i -= 1
      result[i], result[j] = result[j], result[i]
    end
    result
  end
end
