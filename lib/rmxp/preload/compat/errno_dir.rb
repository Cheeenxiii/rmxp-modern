# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# On Windows, File.open on a directory raises EACCES; on Linux it raises
# EISDIR. Essentials games often rescue only EACCES/ENOENT.
class << File
  alias __rmxp_file_open open unless method_defined?(:__rmxp_file_open)
  def open(path, *args, &block)
    __rmxp_file_open(path, *args, &block)
  rescue Errno::EISDIR
    raise Errno::EACCES, path.to_s
  end
end
