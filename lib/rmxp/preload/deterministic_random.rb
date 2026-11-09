# Deterministic RNG shim for mkxp-z.
#
# Loaded as a preload script, after lib/rmxp/mt19937.rb has been concatenated
# in front (the same code used by the tests). Replaces Kernel#rand, srand,
# Random's class methods, Random.new and the random methods of Array.
#
# The seed comes from RMXP_SEED (default 1). Two runs with the same seed and
# the same inputs must draw the same numbers.
module Rmxp
  module Deterministic
    SEED = (ENV["RMXP_SEED"] || "1").to_i

    @seed = SEED
    @global = MT19937.new(SEED)

    class << self
      attr_reader :seed

      def rand(*args)
        CRubyRandom.kernel_rand(@global, args)
      end

      def random_rand(*args)
        CRubyRandom.random_rand(@global, args)
      end

      def srand(new_seed = nil)
        old = @seed
        @seed = new_seed.nil? ? SEED : new_seed.to_i
        @global = MT19937.new(@seed)
        old
      end

      def random_new(seed = nil)
        DeterministicRandom.new(seed.nil? ? SEED : seed.to_i)
      end

      def bytes(count)
        @global.bytes(count)
      end

      def sample(array, n = :none)
        length = array.length
        if n == :none
          return nil if length.zero?
          return array[0] if length < 2

          return array[@global.limited_rand(length - 1)]
        end

        n = n.to_int
        raise ArgumentError, "negative sample number" if n.negative?

        n = length if n > length
        return [] if n.zero?
        return [array[0]] if n == 1

        # CRuby draws one index per picked element, then inserts in order.
        picks = []
        i = 0
        while i < n
          picks << @global.limited_rand(length - i - 1)
          i += 1
        end
        if n <= 10
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
          return sorted.map { |index| array[index] }
        end

        # Large n: same partial Fisher-Yates as CRuby's fallback path.
        result = array.dup
        i = 0
        while i < n
          j = @global.limited_rand(length - i - 1) + i
          result[i], result[j] = result[j], result[i]
          i += 1
        end
        result[0, n]
      end

      def shuffle(array)
        result = array.dup
        i = result.length
        while i > 0
          j = @global.limited_rand(i - 1)
          i -= 1
          result[i], result[j] = result[j], result[i]
        end
        result
      end

      def shuffle!(array)
        i = array.length
        while i > 0
          j = @global.limited_rand(i - 1)
          i -= 1
          array[i], array[j] = array[j], array[i]
        end
        array
      end
    end
  end
end

module Kernel
  def rand(*args)
    Rmxp::Deterministic.rand(*args)
  end

  def srand(new_seed = nil)
    Rmxp::Deterministic.srand(new_seed)
  end

  private :rand, :srand
end

class << Kernel
  def rand(*args)
    Rmxp::Deterministic.rand(*args)
  end

  def srand(new_seed = nil)
    Rmxp::Deterministic.srand(new_seed)
  end
end

class Random
  class << self
    def rand(*args)
      Rmxp::Deterministic.random_rand(*args)
    end

    def srand(new_seed = nil)
      Rmxp::Deterministic.srand(new_seed)
    end

    def new(seed = nil)
      Rmxp::Deterministic.random_new(seed)
    end

    def new_seed
      Rmxp::Deterministic.seed
    end

    def seed
      Rmxp::Deterministic.seed
    end

    def bytes(count)
      Rmxp::Deterministic.bytes(count)
    end
  end
end

if Random.const_defined?(:DEFAULT, false)
  Random.send(:remove_const, :DEFAULT)
  Random.const_set(:DEFAULT, Rmxp::DeterministicRandom.new(ENV["RMXP_SEED"].to_i))
end

class Array
  def sample(n = :none, **kwargs)
    Rmxp::Deterministic.sample(self, n)
  end

  def shuffle(**kwargs)
    Rmxp::Deterministic.shuffle(self)
  end

  def shuffle!(**kwargs)
    Rmxp::Deterministic.shuffle!(self)
  end
end
