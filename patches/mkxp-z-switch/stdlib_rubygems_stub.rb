# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Le build Ruby du port n'installe pas RubyGems. Certains jeux Essentials
# (Reborn) appellent `gem 'rubygems'` au démarrage sans utiliser l'API ensuite.
module Gem
  VERSION = "stub"
end
$LOADED_FEATURES << "rubygems.rb" unless $LOADED_FEATURES.include?("rubygems.rb")
