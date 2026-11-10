# SPDX-License-Identifier: GPL-2.0-or-later
# From GQster's mkxp-z Switch port.
#
# Switch has no native DLLs, so desktop MiniFFI (which normally defines
# Win32API) is not built. This base class behaves like a MiniFFI that failed
# to bind, so win32_wrap.rb (loaded next) can wrap it: wrapped functions use
# its Ruby implementations, everything else returns 0.

# real: stands in for MiniFFI, which the Switch build does not have. The Ruby
# implementations in win32_wrap.rb, loaded next, wrap this class.
class Win32API
	def initialize(dll, func, *args)
		raise RuntimeError, "Win32API is unavailable on Switch (#{dll}:#{func})"
	end

	# disabled: a function without a Ruby implementation returns 0; the game
	# keeps running but whatever it asked for is lost.
	def call(*args)
		return 0
	end

	def Call(*args)
		return call(*args)
	end
end
