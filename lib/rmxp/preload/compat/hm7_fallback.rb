# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: CC0-1.0
#
# Changes made in rmxp-modern are released under CC0.

# H-Mode7 fallback ------------------------------------------------------------
#
# MGC's H-Mode7 plugin (Insurgence and other RMXP games) binds MGC_Hmode7.dll
# through Win32API when its script loads, and has no "DLL missing" branch. With
# win32_wrap.rb the bindings are created anyway and every call returns 0, so
# HM7::Tilemap keeps an empty render bitmap and Spriteset_Map never builds the
# normal Tilemap: the map shows only its panorama, or black.
#
# The plugin decides H-Mode7 maps in Game_Map#setup by setting
# $game_system.hm7, then Spriteset_Map#initialize picks HM7::Tilemap or the
# normal Tilemap from that flag. The flag is also read by the games' own
# H-Mode7-era code (Insurgence's Soar HUD and landing prompt), so forcing it to
# false fixes the map but silently disables those features. Instead, when the
# DLL is confirmed unloadable, keep the flag and replace only the renderer with
# the plugin's own original path:
# - Spriteset_Map#initialize/update/dispose use the aliased normal methods, so
#   the normal Tilemap and Sprite_Character objects are built and updated;
# - the plugin's projection/camera helpers (Game_Character#screen_y and
#   Game_Player#center) call the originals they aliased;
# - Spriteset_Map#hm7_* (camera setters) become no-ops, as the normal Tilemap
#   has no projection to drive.
# The game still sees hm7=true, so its H-Mode7-gated Soar logic keeps working.
#
# This is generic: it only hooks classes and aliases that the H-Mode7 plugin
# itself defines. A game without the plugin gets nothing but the
# Win32API.dll_available? helper.

class Win32API
	class << self
		# false only when a Win32API for that DLL failed to load. An untried
		# DLL counts as available, so callers react to a confirmed absence.
		def dll_available?(name)
			key = __rmxp_dll_key(name)
			dlls = @__rmxp_dlls || {}
			dlls.key?(key) ? dlls[key] : true
		end

		def __rmxp_dll_key(name)
			name.to_s.tr("\\", "/").split("/").last.to_s.sub(/\.dll\z/i, "").downcase
		end

		def __rmxp_record_dll(name, available)
			@__rmxp_dlls ||= {}
			@__rmxp_dlls[__rmxp_dll_key(name)] = available
		end
	end

	alias_method :__rmxp_initialize, :initialize unless method_defined?(:__rmxp_initialize) || private_method_defined?(:__rmxp_initialize)
	def initialize(dll, func, *args)
		__rmxp_initialize(dll, func, *args)
	ensure
		available = !!(@mkxp_wrap_impl || @mkxp_native_available)
		Win32API.__rmxp_record_dll(dll, available)
	end
end

module HMode7Fallback
	DLL = "MGC_Hmode7"
	# aliases the plugin creates for the normal implementation, by class then
	# method (the same method name can mean different aliases per class)
	NORMAL = {
		"Spriteset_Map" => {
			:initialize => :initialize_hm7_spriteset_map,
			:update => :update_hm7_spriteset_map,
			:dispose => :dispose_hm7_spriteset_map,
		},
		"Game_Character" => {
			:update => :update_hm7_game_character,
			:screen_y => :screen_y_hm7_game_character,
		},
		"Game_Player" => {
			:center => :center_hm7_game_player,
		},
		"Game_Map" => {
			:scroll_down => :scroll_down_hm7_game_map,
			:scroll_left => :scroll_left_hm7_game_map,
			:scroll_right => :scroll_right_hm7_game_map,
			:scroll_up => :scroll_up_hm7_game_map,
			:valid? => :valid_hm7_game_map?,
			:passable? => :passable_hm7_game_map?,
		},
	}.freeze

	class << self
		def unavailable?
			return true if @unavailable
			return false unless Win32API.dll_available?(DLL) == false
			@unavailable = true
			System.puts("[preload] H-Mode7 renderer disabled: #{DLL}.dll is not loadable, using the normal Tilemap")
			true
		end

		def hook(mod, name)
			return if @installing
			return unless mod.is_a?(Class)
			case mod.name
			when "Spriteset_Map"
				if name.to_s.start_with?("hm7_")
					hook_noop(mod, name)
				else
					hook_normal(mod, name)
				end
			when "Game_Character", "Game_Player", "Game_Map"
				hook_normal(mod, name)
			end
		end

		def hook_normal(mod, name)
			normal = (NORMAL[mod.name] || {})[name]
			return unless normal
			return unless mod.method_defined?(normal) || mod.private_method_defined?(normal)
			@installing = true
			mod.class_eval do
				alias_method :"__rmxp_hm7_#{name}", name
				define_method(name) do |*args|
					if HMode7Fallback.unavailable?
						send(normal, *args)
					else
						send(:"__rmxp_hm7_#{name}", *args)
					end
				end
			end
		ensure
			@installing = false
		end

		def hook_noop(mod, name)
			@installing = true
			mod.class_eval do
				alias_method :"__rmxp_hm7_original_#{name}", name
				define_method(name) do |*args|
					return nil if HMode7Fallback.unavailable?
					send(:"__rmxp_hm7_original_#{name}", *args)
				end
			end
		ensure
			@installing = false
		end
	end
end

class Module
	unless method_defined?(:__rmxp_method_added) || private_method_defined?(:__rmxp_method_added)
		alias_method :__rmxp_method_added, :method_added
	end
	def method_added(name)
		__rmxp_method_added(name)
		HMode7Fallback.hook(self, name)
	end
	private :method_added
end
