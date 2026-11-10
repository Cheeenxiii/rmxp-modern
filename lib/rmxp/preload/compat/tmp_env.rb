# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# real: Essentials games use ENV["TEMP"] for temporary files, which only
# Windows sets. Provide a writable directory; on the Switch there is no /tmp,
# so create one on the SD card.
def __rmxp_temp_directory
  candidates = []
  candidates << ENV["TMPDIR"] if ENV["TMPDIR"]
  candidates << ENV["TMP"] if ENV["TMP"]
  candidates << "/tmp"
  if Dir.pwd.start_with?("sdmc:") || Dir.exist?("sdmc:/")
    candidates << "sdmc:/switch/mkxp-z/tmp"
  end
  candidates.each do |candidate|
    next if candidate.nil? || candidate.empty?
    begin
      Dir.mkdir(candidate) unless Dir.exist?(candidate)
      next unless Dir.exist?(candidate)
      probe = File.join(candidate, ".rmxp-write-test")
      File.write(probe, "")
      File.delete(probe)
      return candidate
    rescue SystemCallError
      next
    end
  end
  "."
end

temp = __rmxp_temp_directory
ENV["TEMP"] = temp
ENV["TMP"] = temp
