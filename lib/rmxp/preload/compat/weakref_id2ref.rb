# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# real: Uranium-era Essentials replace Ruby's WeakRef with a class based on
# ObjectSpace._id2ref. On the Switch Ruby, _id2ref returns nil for an object
# that has been collected while the id maps still report the reference alive,
# so BitmapCache#fromCache calls disposed? on nil and the game aborts (the
# intro freezes on its last frame with the music still playing). Make
# weakref_alive? and __getobj__ agree that a nil _id2ref means dead: the cache
# then reloads the bitmap instead of dereferencing nil.
if defined?(WeakRef) && WeakRef.class_variable_defined?(:@@id_map)
  class WeakRef
    def __getobj__
      return nil unless WeakRef.class_variable_get(:@@id_rev_map)[__id__] == @__id

      ObjectSpace._id2ref(@__id)
    rescue RangeError
      nil
    end

    def weakref_alive?
      return false unless WeakRef.class_variable_get(:@@id_rev_map)[__id__] == @__id

      !ObjectSpace._id2ref(@__id).nil?
    rescue RangeError
      false
    end
  end
end

# real: the same old BitmapCache judges a cache entry with obj.disposed?. With
# the broken WeakRef above the entry can be a WeakRef delegating to nil, which
# raises NoMethodError and aborts the game. Treat any failure as a cache miss.
if defined?(BitmapCache) && BitmapCache.respond_to?(:fromCache)
  module BitmapCache
    class << self
      alias_method :__rmxp_from_cache, :fromCache unless method_defined?(:__rmxp_from_cache)
      def fromCache(key)
        obj = __rmxp_from_cache(key)
        return nil if obj.nil?

        obj.disposed? ? nil : obj
      rescue StandardError
        nil
      end
    end
  end
end
