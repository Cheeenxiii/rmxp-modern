#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Round-trip test over the corpus. This is the main acceptance test:
# unpack(game) -> build -> the data must reload identically.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rmxp"
require "fileutils"

games = ARGV.empty? ? [] : ARGV
if games.empty?
  abort "usage: test/roundtrip_test.rb GAME [GAME...]"
end

work_root = File.expand_path("../tmp/test", __dir__)
FileUtils.mkdir_p(work_root)
failures = 0

games.each do |game|
  work = File.join(work_root, File.expand_path(game).sub(Dir.pwd + "/", "").gsub(/[^A-Za-z0-9_.-]+/, "__"))
  begin
    report = Rmxp::Project.new(File.expand_path(game)).roundtrip(work)
    puts format("%-46s files=%-4d identical=%-4d equivalent=%-3d opaque=%-2d scripts=%s",
                report["game"], report["files"], report["byte_identical"],
                report["semantic_identical"], report["opaque"], report["scripts"] == 1 ? "ok" : "FAIL")
  rescue StandardError => e
    failures += 1
    puts "FAIL #{game}: #{e.message}"
  end
end

exit(failures.zero? ? 0 : 1)
