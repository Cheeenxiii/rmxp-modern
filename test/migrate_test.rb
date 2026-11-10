#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Regression tests for the bin/rmxp migrate transformations.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rmxp"
require "tmpdir"
require "fileutils"

migrate = Rmxp::Migrate.allocate
cases = {
  "case x\nwhen 0: y=1\nend\n" => "case x\nwhen 0 then y=1\nend\n",
  "case x\nwhen IO::SEEK_SET then y=1\nend\n" => "case x\nwhen IO::SEEK_SET then y=1\nend\n",
  "case x\nwhen :foo then y=1\nend\n" => "case x\nwhen :foo then y=1\nend\n",
  "def f\n  return 1\n  break\nend\n" => "def f\n  return 1\n  raise LocalJumpError, \"break outside loop\"\nend\n",
  "case x\nwhen 0: y\nend\n" => "case x\nwhen 0 then y\nend\n",
  "x = f.read(1)[0]\n" => "x = f.read(1).getbyte(0)\n",
  "class String\n  alias getbyte []\nend\n" => "class String\n  nil\nend\n",
  "class String\n  alias setbyte []= \nend\n" => "class String\n  nil\nend\n",
  "class String\n  alias getbyte other\nend\n" => "class String\n  alias getbyte other\nend\n",
  "g { return 1 }\n" => "g { next 1 }\n",
  "p = proc {\n  return if x\n  1\n}\n" => "p = proc {\n  next if x\n  1\n}\n",
  "def f\n  g { return 1 }\nend\n" => "def f\n  g { return 1 }\nend\n",
  "l = lambda { return 1 }\n" => "l = lambda { return 1 }\n",
}
failures = 0
cases.each do |source, expected|
  got, = migrate.send(:transform_source, source)
  next if got == expected

  failures += 1
  puts "FAIL\nexpected: #{expected.inspect}\ngot:      #{got.inspect}"
end

archive_dir = Dir.mktmpdir("rmxp-migrate-archive")
begin
  File.write(File.join(archive_dir, "Game.rgssad"), "")
  begin
    Rmxp::Migrate.new(archive_dir, File.join(archive_dir, "out")).run
    failures += 1
    puts "FAIL a source with Game.rgssad was not refused"
  rescue ArgumentError => e
    raise unless e.message.include?("extract the archive")
  end
ensure
  FileUtils.remove_entry(archive_dir)
end

# GIF conversion: a tiny animated GIF becomes PNG frames plus a manifest.
if system("ffmpeg", "-version", out: File::NULL, err: File::NULL) &&
   system("ffprobe", "-version", out: File::NULL, err: File::NULL)
  gif_dir = Dir.mktmpdir("rmxp-migrate-gif")
  begin
    pictures = File.join(gif_dir, "Graphics", "Pictures")
    FileUtils.mkdir_p(pictures)
    gif = File.join(pictures, "tiny.gif")
    if system("ffmpeg", "-y", "-v", "error", "-f", "lavfi",
              "-i", "testsrc=size=8x8:rate=10:duration=0.4", "-loop", "0", gif,
              out: File::NULL, err: File::NULL)
      converter = Rmxp::Migrate.allocate
      converter.instance_variable_set(:@out_dir, gif_dir)
      converted = converter.send(:convert_gifs)
      frames = Dir.glob(File.join(pictures, "tiny.frames", "frame*.png"))
      manifest = File.join(gif_dir, "gif_frames.txt")
      line = if File.file?(manifest)
               File.readlines(manifest).find { |entry| entry.start_with?("tiny_tmp_") }
             end
      dir, delays = line.to_s.chomp.split("\t")[1, 2]
      expected = converted.length == 1 && frames.length == 4 &&
                 dir == "Graphics/Pictures/tiny.frames" && delays == "10,10,10,10"
      unless expected
        failures += 1
        puts "FAIL gif conversion: converted=#{converted.inspect} frames=#{frames.length} manifest=#{line.inspect}"
      end
    else
      puts "migrate: gif test skipped (ffmpeg could not create a GIF)"
    end
  ensure
    FileUtils.remove_entry(gif_dir)
  end
else
  puts "migrate: gif test skipped (ffmpeg not found)"
end

puts failures.zero? ? "migrate: ok" : "migrate: #{failures} failure(s)"
exit(failures.zero? ? 0 : 1)
