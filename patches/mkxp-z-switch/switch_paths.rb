# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Après le chdir du port dans le dossier du jeu, rendre les chemins absolus
# visibles à require (les jeux Essentials poussent des chemins relatifs
# comme "stdlib" ou "preload" dans $LOAD_PATH).
root = Dir.pwd
["romfs:/stdlib", ".", "stdlib", "gems"].each do |sub|
  path = sub.start_with?("romfs:") ? sub : File.expand_path(sub, root)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end
