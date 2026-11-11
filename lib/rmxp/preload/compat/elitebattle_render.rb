# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: CC0-1.0
#
# Changes made in rmxp-modern are released under CC0.

# EliteBattle battle render cache ---------------------------------------------
#
# Luka S.J.'s EliteBattle plugin (used by many Essentials v16/v17 fangames)
# rebuilds every battler's ground shadow on every battle frame:
#
#   DynamicPokemonSprite#update
#     @sprite.bitmap = @bitmap.bitmap.clone
#     @shadow.bitmap = @bitmap.bitmap.clone
#     @shadow.skew(@vector.angle + 49)
#
# Sprite#skew draws the shadow with one blt per source row (roughly 300 rows
# per battler), and the two clones copy the whole sprite bitmap. The camera
# angle changes by tiny asymptotic steps, so most re-skews produce exactly the
# same rows.
#
# This preload keeps the sprite clone until the animation frame changes, and
# reuses a skew result while no source row can cross an integer destination
# offset. The test is conservative: it reuses only when (rows-1) * |1/tan -
# 1/tan'| is below the closest row-to-integer distance, so every blt would land
# on the same pixel. Anything else falls back to the plugin's own methods.
#
# Generic: it only hooks classes and methods the plugin itself defines. A game
# without EliteBattle is untouched.

module EliteBattleRender
  module SkewCache
    def skew(angle = 90)
      # The plugin's own performance switch drops the shadow shear.
      return super if $PokemonSystem && $PokemonSystem.performance
      bmp = self.bitmap
      return super if !bmp || bmp.disposed?
      return super if bmp.height < 2
      tan = Math.tan(angle * (Math::PI / 180.0))
      return super unless tan > 0.0

      h = bmp.height
      width = (bmp.width + (h - 1) / tan).to_i
      inv = 1.0 / tan
      if @eb_skew_src.equal?(bmp) && @eb_skew_min &&
         @eb_skew_width == width && @eb_skew_result && !@eb_skew_result.disposed?
        delta = (@eb_skew_inv - inv).abs * (h - 1)
        if delta * 1.0000001 < @eb_skew_min
          self.bitmap = @eb_skew_result
          return true
        end
      end

      old = @eb_skew_result
      super
      return false unless self.bitmap && !self.bitmap.disposed?
      if old && !old.disposed? && !old.equal?(bmp) && !old.equal?(self.bitmap)
        old.dispose
      end
      @eb_skew_src = bmp
      @eb_skew_inv = inv
      @eb_skew_width = width
      @eb_skew_result = self.bitmap
      @eb_skew_min = EliteBattleRender.min_boundary(h, tan)
      true
    end
  end

  module UpdatePatch
    def update(angle = 74)
      unless @bitmap.is_a?(AnimatedBitmapWrapper)
        return super
      end
      return if @lock
      return if !@bitmap || @bitmap.disposed?
      @bitmap.update
      index = @bitmap.currentIndex
      if @eb_render_index != index
        @eb_render_index = index
        old = @eb_render_sprite
        @eb_render_sprite = @bitmap.bitmap.clone
        @sprite.bitmap = @eb_render_sprite
        old.dispose if old && !old.disposed? && !old.equal?(@eb_render_sprite)
        EliteBattleRender.invalidate_skew(@shadow)
      end
      @shadow.bitmap = @bitmap.bitmap
      @shadow.skew(angle)
      case @status
      when 0 then @sprite.color = Color.new(0, 0, 0, 0)
      when 1 then @sprite.color = Color.new(153, 102, 204, 50)
      when 2 then @sprite.color = Color.new(255, 255, 153, 50)
      when 3 then @sprite.color = Color.new(153, 204, 204, 50)
      when 4 then @sprite.color = Color.new(204, 51, 51, 50)
      end
      @frame += 1
      @sprite.visible = (@frame % 10 < 7) if @selected == 2
      formatShadow
    end
  end

  class << self
    def installed?
      !!@installed
    end

    # Smallest distance between any row's destination offset and an integer
    # (row 0 is always at 0 and never moves). 0 means no safe reuse.
    def min_boundary(h, tan)
      min = 1.0
      i = 1
      while i < h
        x = i / tan
        d = x - x.floor
        d = 1.0 - d if d > 0.5
        min = d if d < min
        return 0.0 if min == 0.0
        i += 1
      end
      min
    end

    def invalidate_skew(sprite)
      sprite.instance_variable_set(:@eb_skew_src, nil) if sprite
    end

    def install
      return if @installed
      return unless defined?(DynamicPokemonSprite) && defined?(AnimatedBitmapWrapper)
      return unless Sprite.method_defined?(:skew)
      return unless AnimatedBitmapWrapper.method_defined?(:currentIndex)
      return unless DynamicPokemonSprite.method_defined?(:update)
      @installed = true
      @watch.disable if @watch
      Sprite.prepend(SkewCache)
      DynamicPokemonSprite.prepend(UpdatePatch)
    end

    def watch
      return if @watch
      @watch = TracePoint.new(:end) do |tp|
        k = tp.self
        next unless k.is_a?(Class)
        next unless k.name == "DynamicPokemonSprite" || k.name == "AnimatedBitmapWrapper" ||
                    k.name == "Sprite"
        install
      end
      @watch.enable
    end
  end
end

EliteBattleRender.watch if defined?(TracePoint)
