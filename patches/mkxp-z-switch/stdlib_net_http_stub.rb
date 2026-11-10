# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# Le build Ruby du port n'a pas net/http. Reborn le require au démarrage pour
# son updater ; on marque la feature chargée et on laisse l'appel échouer
# proprement (l'updater rattrape les erreurs StandardError).
module Net
  class HTTP
    class Get; end
    def self.start(*_args); raise "net/http disabled in Switch port"; end
  end
end
$LOADED_FEATURES << "net/http.rb" unless $LOADED_FEATURES.include?("net/http.rb")
