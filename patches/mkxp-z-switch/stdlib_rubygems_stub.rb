# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# disabled: the port's Ruby build does not include RubyGems. Some Essentials
# games (Reborn) call `gem 'rubygems'` at startup without using the API
# afterwards; the call is accepted, but no gem can be loaded.
module Gem
  VERSION = "stub"
end
$LOADED_FEATURES << "rubygems.rb" unless $LOADED_FEATURES.include?("rubygems.rb")
