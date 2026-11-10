# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# The port's Ruby build has no net/http. Reborn requires it at startup for
# its updater: mark the feature as loaded and let calls fail cleanly (the
# updater rescues StandardError).
module Net
  class HTTP
    class Get; end
    def self.start(*_args); raise "net/http disabled in Switch port"; end
  end
end
$LOADED_FEATURES << "net/http.rb" unless $LOADED_FEATURES.include?("net/http.rb")
