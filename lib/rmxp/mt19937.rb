# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-FileCopyrightText: 1997-2002 Makoto Matsumoto and Takuji Nishimura
# SPDX-FileCopyrightText: 1993-2013 Yukihiro Matsumoto
# SPDX-License-Identifier: MIT AND BSD-3-Clause AND BSD-2-Clause
#
# Ruby port of CRuby's missing/mt19937.c (BSD-3-Clause, original notice
# below) and of the conversions in random.c (Ruby's BSD-2-Clause option,
# see LICENSES/BSD-2-Clause.txt). The Ruby port itself is MIT so that it can
# ship inside games.
#
#   A C-program for MT19937, with initialization improved 2002/2/10.
#   Coded by Takuji Nishimura and Makoto Matsumoto.
#
#   Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions
#   are met:
#
#     1. Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#
#     2. Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#
#     3. The names of its contributors may not be used to endorse or promote
#        products derived from this software without specific prior written
#        permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
#   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Mersenne Twister MT19937 compatible with CRuby.
#
# The game must draw exactly the same numbers as CRuby would with the same
# seed. This is a direct port of Ruby's missing/mt19937.c and of the
# conversions in random.c (float in [0,1), rand(n), rand(range)).
#
# Used by the tests and, through the preload shim, by the reference run, the
# transformed run and the compiled game.
module Rmxp
  # CRuby's MT19937 with the Cokus optimisation: the state array is consumed
  # in order and regenerated when exhausted.
  class MT19937
    N = 624
    M = 397
    MATRIX_A = 0x9908b0df
    UMASK = 0x80000000
    LMASK = 0x7fffffff
    MASK32 = 0xffffffff
    TWO_POW_32 = 4_294_967_296
    TWO_POW_53 = 9_007_199_254_740_992.0

    attr_reader :seed

    def initialize(seed = 0)
      @seed = seed
      @state = Array.new(N, 0)
      @index = N
      init_from_integer(seed)
    end

    # Raw 32-bit output (genrand_int32).
    def genrand_int32
      twist if @index >= N
      y = @state[@index]
      @index += 1
      y ^= y >> 11
      y ^= (y << 7) & 0x9d2c5680
      y ^= (y << 15) & 0xefc60000
      y ^= y >> 18
      y & MASK32
    end

    # Double in [0, 1), 53-bit resolution (genrand_real).
    def genrand_real
      a = genrand_int32
      b = genrand_int32
      (((a >> 5) << 26) + (b >> 6)) / TWO_POW_53
    end

    # Double in [0, 1], 53-bit resolution (int_pair_to_real_inclusive). Used
    # by rand(range) for non-excluded float ranges.
    def genrand_real_inclusive
      a = genrand_int32
      b = genrand_int32
      (((a << 21) + ((b + (a >> 21)) >> 11))) / TWO_POW_53
    end

    # Uniform integer in [0, limit] (limited_rand), limit fitting in 32 bits.
    def limited_rand(limit)
      return 0 if limit.zero?

      mask = make_mask(limit)
      if limit > MASK32
        raise NotImplementedError, "rand(n) with n > 2**32 is not implemented"
      end

      loop do
        value = genrand_int32 & mask
        return value if value <= limit
      end
    end

    def bytes(count)
      raise ArgumentError, "negative size" if count.negative?

      out = +"".b
      while out.bytesize + 4 <= count
        r = genrand_int32
        4.times do
          out << (r & 0xff).chr
          r >>= 8
        end
      end
      rest = count - out.bytesize
      if rest.positive?
        r = genrand_int32
        rest.times do
          out << (r & 0xff).chr
          r >>= 8
        end
      end
      out
    end

    private

    def init_from_integer(seed)
      words = seed.abs.digits(TWO_POW_32)
      words = [0] if words.empty?
      if words.length <= 1
        init_genrand(words[0] & MASK32)
      else
        # random.c drops a leading 1 guard word before init_by_array, but
        # still calls init_by_array even when the shortened key has one word.
        words = words[0..-2] if words[-1] == 1
        init_by_array(words)
      end
    end

    def init_genrand(seed)
      @state[0] = seed & MASK32
      j = 1
      while j < N
        prev = @state[j - 1]
        @state[j] = (1_812_433_253 * (prev ^ (prev >> 30)) + j) & MASK32
        j += 1
      end
      @index = N
    end

    def init_by_array(key)
      init_genrand(19_650_218)
      i = 1
      j = 0
      k = N > key.length ? N : key.length
      while k.positive?
        prev = @state[i - 1]
        @state[i] = ((@state[i] ^ ((prev ^ (prev >> 30)) * 1_664_525 & MASK32)) +
                     key[j] + j) & MASK32
        i += 1
        j += 1
        if i >= N
          @state[0] = @state[N - 1]
          i = 1
        end
        j = 0 if j >= key.length
        k -= 1
      end
      k = N - 1
      while k.positive?
        prev = @state[i - 1]
        @state[i] = ((@state[i] ^ ((prev ^ (prev >> 30)) * 1_566_083_941 & MASK32)) - i) & MASK32
        i += 1
        if i >= N
          @state[0] = @state[N - 1]
          i = 1
        end
        k -= 1
      end
      @state[0] = 0x80000000
      @index = N
    end

    def twist
      i = 0
      while i < N
        y = (@state[i] & UMASK) | (@state[(i + 1) % N] & LMASK)
        @state[i] = @state[(i + M) % N] ^ (y >> 1) ^ ((y & 1) == 1 ? MATRIX_A : 0)
        i += 1
      end
      @index = 0
    end

    def make_mask(value)
      value |= value >> 1
      value |= value >> 2
      value |= value >> 4
      value |= value >> 8
      value |= value >> 16
      value |= value >> 32
      value
    end
  end

  # CRuby's conversions on top of MT19937: Kernel#rand, Random#rand and
  # rand(range). Kept as functions so the shim and the tests share the code.
  module CRubyRandom
    module_function

    # Kernel#rand: floats when no argument/zero/NaN-ish, integers otherwise,
    # negative maxima give a positive result in 0...abs(max).
    def kernel_rand(mt, args)
      return mt.genrand_real if args.empty?

      max = args[0]
      return mt.genrand_real if max.nil?

      if max.is_a?(Range)
        return range_rand(mt, max)
      end

      int = max.respond_to?(:to_int) ? max.to_int : nil
      if int.is_a?(Integer) && int != 0
        return int >= 0 ? mt.limited_rand(int - 1) : mt.limited_rand(-int - 1)
      end

      mt.genrand_real
    end

    # Random#rand: strict, rejects zero and negative integers/floats.
    def random_rand(mt, args)
      return mt.genrand_real if args.empty?

      max = args[0]
      raise ArgumentError, "invalid argument - nil" if max.nil?

      if max.is_a?(Range)
        return range_rand(mt, max)
      end

      if max.is_a?(Float)
        raise ArgumentError, "invalid argument - #{max}" if max.negative? || max.nan?
        return mt.genrand_real if max.zero?

        return mt.genrand_real * max
      end

      int = max.respond_to?(:to_int) ? max.to_int : nil
      raise ArgumentError, "invalid argument - #{max}" unless int.is_a?(Integer)
      raise ArgumentError, "invalid argument - #{max}" unless int.positive?

      mt.limited_rand(int - 1)
    end

    # Returns nil for an empty range, as CRuby's rand_range does; Kernel#rand
    # returns that nil, Random#rand turns it into an ArgumentError.
    def range_rand(mt, range)
      first = range.begin
      last = range.end
      return nil if first.nil? || last.nil?

      span = last - first
      excl = range.exclude_end?
      if span.is_a?(Float)
        return nil if span.negative?
        return first + 0.0 if span.zero? && !excl
        return nil if span.zero?

        value = excl ? mt.genrand_real : mt.genrand_real_inclusive
        return first + value * span
      end

      span = span.to_int
      max = span - (excl ? 1 : 0)
      return nil if max.negative?

      first + mt.limited_rand(max)
    end
  end

  # A Random-like object backed by our MT19937. Implements the parts games
  # actually use: rand, random_number, bytes, seed.
  class DeterministicRandom
    attr_reader :seed

    def initialize(seed = 0)
      @seed = seed
      @mt = MT19937.new(seed)
    end

    def rand(*args)
      CRubyRandom.random_rand(@mt, args)
    end
    alias random_number rand

    def bytes(count)
      @mt.bytes(count)
    end

    def ==(other)
      other.is_a?(DeterministicRandom) && other.seed == seed
    end

    def inspect
      "#<Rmxp::DeterministicRandom seed=#{seed}>"
    end
  end
end
