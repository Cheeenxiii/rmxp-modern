# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Ruby 1.8 APIs used by Essentials v16 games.
class Thread
  class << self
    def critical; false; end
    def critical=(value); value; end
  end
end
