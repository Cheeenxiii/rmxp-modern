# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

# Compiles the damage kernel (test/battle/hybrid_damage.rb) into a CRuby
# extension with Spinel. Needs the Ruby headers (ruby3.3-dev package) and
# Spinel built in vendor/spinel.
require "rbconfig"

ROOT = File.expand_path("../..", __dir__)
OUT_DIR = File.join(ROOT, "tmp/battle/hybrid")
SPINEL = File.join(ROOT, "vendor/spinel/bin/spinel")
KERNEL = File.join(__dir__, "hybrid_damage.rb")

Dir.mkdir(OUT_DIR) unless Dir.exist?(OUT_DIR)
c_source = File.join(OUT_DIR, "damage.c")
system(SPINEL, KERNEL, "-c", "--no-line-map", "--ext", "cruby",
       "--ext-init", "spx_init_damage", "--ext-entry", "BattleHot.damage",
       "-o", c_source) or abort "Spinel failed"

rubyhdrdir = ENV["RUBY_HDRDIR"] || RbConfig::CONFIG["rubyhdrdir"]
rubyarchhdrdir = ENV["RUBY_ARCHHDIR"] || RbConfig::CONFIG["rubyarchhdrdir"]
local = File.join(ROOT, ".recon/ruby-dev/root/usr/include/ruby-3.3.0")
local_arch = File.join(ROOT, ".recon/ruby-dev/root/usr/include/x86_64-linux-gnu/ruby-3.3.0")
rubyhdrdir = local if !File.file?(File.join(rubyhdrdir, "ruby.h")) && File.file?(File.join(local, "ruby.h"))
rubyarchhdrdir = local_arch if !File.file?(File.join(rubyarchhdrdir, "ruby/config.h")) && File.file?(File.join(local_arch, "ruby/config.h"))
abort "Ruby headers not found (install ruby3.3-dev)" unless File.file?(File.join(rubyhdrdir, "ruby.h"))

sources = [File.join(OUT_DIR, "damage_ext.c"), c_source] +
          Dir.glob(File.join(ROOT, "vendor/spinel/lib/*.c")) +
          Dir.glob(File.join(ROOT, "vendor/spinel/lib/regexp/*.c"))
cc = RbConfig::CONFIG["CC"] || "cc"
out = File.join(OUT_DIR, "damage.so")
system(cc, "-shared", "-fPIC", "-O1", "-w",
       "-I#{rubyhdrdir}", "-I#{rubyarchhdrdir}",
       "-I#{File.join(ROOT, 'vendor/spinel/lib')}",
       "-I#{File.join(ROOT, 'vendor/spinel/lib/regexp')}",
       "-I#{File.join(ROOT, 'vendor/spinel/lib/regexp/shim')}",
       "-I#{OUT_DIR}", *sources, "-lm", "-o", out) or abort "C compilation failed"
puts out
