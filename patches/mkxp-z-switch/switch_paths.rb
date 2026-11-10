# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# real: after the port changes into the game directory, make the load paths
# absolute so require finds them (Essentials games push relative paths such
# as "stdlib" or "preload" onto $LOAD_PATH).
root = Dir.pwd
["romfs:/stdlib", ".", "stdlib", "gems"].each do |sub|
  path = sub.start_with?("romfs:") ? sub : File.expand_path(sub, root)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end
