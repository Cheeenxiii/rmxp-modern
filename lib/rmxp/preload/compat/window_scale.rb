# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# real: old Essentials draw at the game's resolution (512x384 for the v16
# games) and ask the engine to resize the screen. mkxp-z resizes the window
# with it, which leaves the window and the picture the same size. Keep the
# window at the size it had before the game's first resize instead: the engine
# then upscales the picture to the window, as the reference port does.
#
# The window size is whatever the engine started with (mkxp.json defScreenW/H
# or the engine default); nothing is hardcoded.
if defined?(Graphics) && Graphics.respond_to?(:resize_window)
  module RmxpWindowScale
    class << self
      def remember_window
        @window ||= [Graphics.width, Graphics.height]
      end

      def window
        @window
      end

      def restore_later
        @pending = @window
      end

      # Changing the window in the middle of a frame leaves a one-frame
      # artifact, so apply it after the frame has been drawn.
      def apply_pending
        return unless @pending

        window = @pending
        @pending = nil
        Graphics.resize_window(*window)
      end

      # The games only override Graphics.width/height after our preload has
      # run, so the resolution they want is known on the first frame. Make the
      # surface that size and give the window its initial size back; the
      # engine then scales the picture up.
      def follow_game_resolution_on_first_frame
        return if @followed

        @followed = true
        wanted = [Graphics.width, Graphics.height]
        return if wanted == @window

        Graphics.send(:__rmxp_window_scale_resize_screen, *wanted)
        restore_later if wanted[0] < @window[0] || wanted[1] < @window[1]
      end
    end
  end

  RmxpWindowScale.remember_window

  class << Graphics
    alias_method :__rmxp_window_scale_resize_screen, :resize_screen unless method_defined?(:__rmxp_window_scale_resize_screen)
    def resize_screen(width, height)
      RmxpWindowScale.remember_window
      __rmxp_window_scale_resize_screen(width, height)
      window = RmxpWindowScale.window
      RmxpWindowScale.restore_later if width < window[0] || height < window[1]
      nil
    end

    alias_method :__rmxp_window_scale_update, :update unless method_defined?(:__rmxp_window_scale_update)
    def update
      RmxpWindowScale.follow_game_resolution_on_first_frame
      __rmxp_window_scale_update
      RmxpWindowScale.apply_pending
    end
  end
end
