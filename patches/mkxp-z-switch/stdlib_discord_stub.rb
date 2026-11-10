# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Reborn charge la gem native discord (Rich Presence), absente du port.
# Le jeu tolère une présence inactive si les méthodes existent.
module Discord
  def self.connected?; false; end
  def self.connect(*_args); nil; end
  def self.disconnect; nil; end
  def self.update; nil; end
  def self.update_activity(*_args); nil; end
end
$LOADED_FEATURES << "discord.rb" unless $LOADED_FEATURES.include?("discord.rb")
