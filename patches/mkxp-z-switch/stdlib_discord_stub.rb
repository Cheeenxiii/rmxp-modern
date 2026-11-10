# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Reborn loads the native discord gem (Rich Presence), which the port does
# not have. The game copes with an inactive presence if the methods exist.
module Discord
  def self.connected?; false; end
  def self.connect(*_args); nil; end
  def self.disconnect; nil; end
  def self.update; nil; end
  def self.update_activity(*_args); nil; end
end
$LOADED_FEATURES << "discord.rb" unless $LOADED_FEATURES.include?("discord.rb")
