# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# real: Essentials games use ENV["TEMP"] for temporary files, which only
# Windows sets. Provide a valid path on Linux and macOS.
temp = (ENV["TMPDIR"] || ENV["TMP"] || "/tmp")
ENV["TEMP"] ||= temp
ENV["TMP"] ||= temp
