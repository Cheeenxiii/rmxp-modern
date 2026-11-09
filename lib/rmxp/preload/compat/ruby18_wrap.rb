# ruby18_wrap.rb
# Author: Splendide Imaginarius (2022)

# Creative Commons CC0: To the extent possible under law, Splendide Imaginarius
# has waived all copyright and related or neighboring rights to ruby18_wrap.rb.
# https://creativecommons.org/publicdomain/zero/1.0/

# This preload script provides functions that existed in RPG Maker's Ruby v1.8,
# but were renamed in the current Ruby version used in mkxp-z, so that games
# (or other preload scripts) that expect Ruby v1.8's function names can find
# them.

class Hash
  def index(*args)
    key(*args)
  end

  def to_s
    return self.reduce("") do |sentence, (key, value)|
      sentence + "#{key.to_s}#{to_s}"
    end
  end
end

class Array
  def to_s
    return self.join("")
  end
end

class Time
  def to_s
    return strftime("%a %b %d %H:%M:%S %Z %Y")
  end
end

#===============================================================================
# Marshal serialization fix
#-----------------------------------------------------------------------------
module MarshalWrapper

  # Recursively copy an object graph, forcing every String to BINARY
  # encoding while preserving shared references and circular references.
  def to_binary(obj, seen = {})
    case obj
    when String
      id = obj.object_id
      return seen[id] if seen.key?(id)

      copy = obj.dup
      seen[id] = copy
      copy.force_encoding(Encoding::BINARY)
      
      copy

    when Array
      id = obj.object_id
      return seen[id] if seen.key?(id)

      copy = []
      seen[id] = copy

      obj.each do |value|
        copy << to_binary(value, seen)
      end

      copy

    when Hash
      id = obj.object_id
      return seen[id] if seen.key?(id)

      copy = {}
      seen[id] = copy

      obj.each do |key, value|
        copy[to_binary(key, seen)] = to_binary(value, seen)
      end

      copy

    when Numeric, Symbol, TrueClass, FalseClass, NilClass
      obj

    when Time
      # Ruby 1.8 Marshal has no :offset/:zone ivars; emit the old 8-byte
      # [seconds, microseconds] _dump so the endpoint sees plain "u :Time".
      copy = obj.dup
      def copy._dump(depth = -1)
        [to_i, usec].pack("ii")
      end
      copy

    else
      id = obj.object_id

      # Return the copy if this object has already been visited.
      return seen[id] if seen.key?(id)
      # Fall back to duplicating ordinary objects.
      copy = begin
               obj.dup
             rescue TypeError
               # Some special objects cannot be duplicated.
               # Returning the original may still cause Marshal.dump to fail.
               obj
             end

      seen[id] = copy

      # Recursively copy instance variables.
      obj.instance_variables.each do |iv|
        value = obj.instance_variable_get(iv)
        ivs_value = obj.instance_variable_get(:@iv)
        converted = to_binary(value, seen)
        # This field needs to be retroactively fixed for
        # any saves that ever went through the port...
        # Can probably be removed once a significant enough
        # amount of time passes that all the "bad" saves are fixed.
        if iv == :@oiv
          converted = to_binary(value.gsub(/\D/, ''))
        end

        begin
          copy.instance_variable_set(iv, converted)
        rescue TypeError, FrozenError
          # Some objects cannot have their instance variables changed.
        end
      end

      copy
    end
  end

  def dump(obj, *args)
    super(to_binary(obj), *args)
  end
end

# Hook it into Marshal's singleton class
Marshal.singleton_class.prepend(MarshalWrapper)
