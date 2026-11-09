# Compléments Ruby 1.8 génériques utilisés par les jeux Essentials v16.
class Thread
  class << self
    def critical; false; end
    def critical=(value); value; end
  end
end
