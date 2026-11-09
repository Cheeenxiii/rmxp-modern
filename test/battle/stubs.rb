$DEBUG = false
$TEST = false
$INTERNAL = true

module Graphics
  @width = 512
  @height = 384
  @frame_rate = 40
  @frame_count = 0
  @brightness = 255
  class << self
    attr_accessor :width, :height, :frame_rate, :frame_count, :brightness
    def update(*); @frame_count += 1; end
    def transition(*); nil; end
    def freeze; nil; end
    def wait(*); nil; end
    def resize_screen(*); nil; end
    def snap_to_bitmap; Bitmap.new(32, 32); end
    def play_movie(*); nil; end
    def frame_reset; end
  end
end

class Bitmap
  attr_accessor :width, :height
  def self.max_size; 8192; end
  def max_size; 8192; end
  def initialize(*_args); @width = 32; @height = 32; end
  def dispose; end
  def draw_text(*_a); end
  def blt(*_a); end
  def blt_bitmap(*_a); end
  def fill_rect(*_a); end
  def clear; end
  def get_pixel(*_a); Color.new(0, 0, 0, 255); end
  def set_pixel(*_a); end
  def text_size(*_a); [0, 0]; end
  def stretch_blt(*_a); end
  def hue_change(*_a); end
  def to_bitmap; self; end
end
class Color; def initialize(*_a); end; end
class Tone; def initialize(*_a); end; end
class Rect
  attr_accessor :x, :y, :width, :height
  def initialize(x = 0, y = 0, w = 0, h = 0); @x = x; @y = y; @width = w; @height = h; end
  def empty?; true; end
end
class Font; def initialize(*_a); end; end
class Table
  def initialize(*_a); end
  def [](*_a); 0; end
  def []=(*_a); end
end
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :zoom_x, :zoom_y, :opacity, :visible,
                :src_rect, :color, :tone, :blend_type, :mirror, :angle, :viewport,
                :wave_amplitude, :wave_length, :wave_speed, :wave_phase
  def initialize(*_a); end
end
class Viewport
  attr_accessor :z, :visible, :rect, :color, :tone
  def initialize(*_a); end
end
class Window
  attr_accessor :x, :y, :width, :height, :z, :visible, :opacity, :contents, :active,
                :pause, :cursor_rect, :viewport, :stretch, :openness
  def initialize(*_a); end
  def update; end
  def dispose; end
end
class Plane
  attr_accessor :bitmap, :visible, :z, :opacity, :ox, :oy, :zoom_x, :zoom_y
  def initialize(*_a); end
end
class Tilemap; def initialize(*_a); end; end

module Input
  DOWN = 2
  LEFT = 4
  RIGHT = 6
  UP = 8
  ACTION = 11
  BACK = 12
  USE = 13
  RUN = 14
  JUMP = 15
  SPECIAL = 16
  A = 1
  B = 2
  C = 4
  X = 8
  Y = 16
  Z = 32
  L = 64
  R = 128
  SHIFT = 256
  CTRL = 512
  ALT = 1024
  F5 = 2048
  F6 = 4096
  F7 = 8192
  F8 = 16_384
  F9 = 32_768
  F10 = 65_536
  F11 = 131_072
  F12 = 262_144
  class << self
    def update; end
    def press?(*_a); false; end
    def trigger?(*_a); false; end
    def repeat?(*_a); false; end
    def dir4; 0; end
    def dir8; 0; end
    def text_input; nil; end
    def set_text_input(*_a); end
    def clipboard; nil; end
    def clipboard=(_v); end
    def mouse_in_window; false; end
    def mouse_x; 0; end
    def mouse_y; 0; end
  end
end

module Audio
  class << self
    def bgm_play(*_a); end
    def bgm_stop; end
    def bgm_fade(*_a); end
    def bgm_pos; nil; end
    def bgm_pause; end
    def bgm_resume; end
    def bgs_play(*_a); end
    def bgs_stop; end
    def me_play(*_a); end
    def me_stop; end
    def se_play(*_a); end
    def se_stop; end
    def setup_midi(*_a); end
  end
end

module System
  def self.uptime; Process.clock_gettime(Process::CLOCK_MONOTONIC); end
  def self.delta; 0.0; end
  def self.puts(*_a); end
  def self.user_language; "en"; end
  def self.data_directory; "."; end
  def self.user_name; "PLAYER"; end
  VERSION = "2.4.2"
end

module RTP
  def self.getSaveFileName(file); file; end
  def self.getFileName(file); file; end
end

def load_data(path)
  Marshal.load(File.binread(path))
end

def save_data(path, obj)
  File.binwrite(path, Marshal.dump(obj))
end
