# Certains jeux Essentials poussent des chemins relatifs ("stdlib") dans
# $LOAD_PATH ; le require natif du port ne résout pas toujours romfs:/ ou
# sdmc:/. On garde une roue de secours pour les stdlib embarquées dans le
# RomFS du port (timeout, weakref, delegate).
module Kernel
  class << self
    alias __rmxp_original_require require unless method_defined?(:__rmxp_original_require)
  end

  def require(name)
    Kernel.__rmxp_original_require(name)
  rescue LoadError
    path = "romfs:/stdlib/#{name}.rb"
    if File.file?(path)
      load path
      $LOADED_FEATURES << "#{name}.rb" unless $LOADED_FEATURES.include?("#{name}.rb")
      return true
    end
    raise
  end
end
