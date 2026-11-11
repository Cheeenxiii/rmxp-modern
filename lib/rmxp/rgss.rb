# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# RGSS value types that Marshal stores in their own binary format.
#
# RMXP data files contain Table, Color, Tone and Rect values. They are not
# plain Ruby objects: Marshal calls their `_dump`/`_load`. The codec turns
# Table payloads into readable integers; Color, Tone, Rect and Font are kept
# verbatim. Either way the round trip is byte-identical.
class RmxpBlob
  attr_reader :payload

  def self._load(payload)
    allocate.tap { |value| value.instance_variable_set(:@payload, payload) }
  end

  def _dump(_depth)
    @payload
  end

  def ==(other)
    other.class == self.class && other.payload == payload
  end

  alias eql? ==

  def hash
    [self.class, payload].hash
  end
end

class Table < RmxpBlob; end
class Color < RmxpBlob; end
class Tone < RmxpBlob; end
class Rect < RmxpBlob; end
class Font < RmxpBlob; end
