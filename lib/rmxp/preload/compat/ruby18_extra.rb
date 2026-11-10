# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Ruby 1.8 APIs used by Essentials v16 games.
class Thread
  class << self
    # disabled: Ruby 1.8's global thread lock is gone, so the protection
    # against thread switches during audio and bitmap-cache updates is lost.
    # The games use it only around those caches; no visible race was seen.
    def critical; false; end
    def critical=(value); value; end
  end
end
