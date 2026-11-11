# SPDX-License-Identifier: CC0-1.0
# Some pre-v19 Essentials games install their TrueType fonts into the Windows
# font folder and offer to restart the game. Neither works here: the copy
# lands at a literal "\Windows\Fonts\" path and the restart kills the
# process. mkxp-z renders text with the system fonts, so skip the installer.
module RmxpFontInstallerCompat
	def install
		true
	end
end

module Graphics
	class << self
		alias_method :rmxp_font_installer_update, :update unless method_defined?(:rmxp_font_installer_update)
		def update
			unless $rmxp_font_installer_hooked
				if defined?(FontInstaller) && FontInstaller.respond_to?(:install)
					FontInstaller.singleton_class.prepend(RmxpFontInstallerCompat)
					$rmxp_font_installer_hooked = true
				end
			end
			rmxp_font_installer_update
		end
	end
end
