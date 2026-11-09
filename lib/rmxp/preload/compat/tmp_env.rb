# Les jeux Essentials Windows utilisent ENV["TEMP"] pour des fichiers
# temporaires. Sous Linux/macOS, fournir un chemin valide.
require "tmpdir" rescue nil
temp = (ENV["TMPDIR"] || ENV["TMP"] || "/tmp")
ENV["TEMP"] ||= temp
ENV["TMP"] ||= temp
