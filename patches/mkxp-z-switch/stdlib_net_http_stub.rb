# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# disabled: the port's Ruby build has no net/http. Reborn requires it at
# startup for its updater: the feature is marked as loaded and calls fail
# cleanly (the updater rescues StandardError), but no request is ever made.
module Net
  class HTTP
    class Get; end
    def self.start(*_args); raise "net/http disabled in Switch port"; end
  end
end
$LOADED_FEATURES << "net/http.rb" unless $LOADED_FEATURES.include?("net/http.rb")
