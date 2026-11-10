# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "fileutils"
require "shellwords"

module Rmxp
  # Turns a migrated game into ready-to-play folders with the engine bundled.
  class Package
    PLATFORMS = %w[linux windows].freeze

    # Source-side leftovers that have no use in a player package.
    SKIP = %w[scripts scripts.yml errorlog.txt].freeze
    # Saves and per-player settings live at the game root; they are not part
    # of a distributable game, whatever the game names them.
    SKIP_PATTERNS = [/\A.*\.exe\z/i, /\A.*\.dll\z/i, /\A.*\.lnk\z/i,
                     /\A.*\.rgssad\z/i, /\A.*\.rgss2a\z/i, /\A.*\.rgss3a\z/i,
                     /\A.*\.rxproj\z/i, /\Aerrorlog\.txt\z/i, /\A.*\.log\z/i,
                     /\A.*\.rxdata(?:\.bak)?\z/i].freeze
    # Never bundle these system libraries; every Linux target has them.
    SYSTEM_LIBS = [/\Ald-linux/, /\Alibc\.so/, /\Alibm\.so/, /\Alibgcc_s\.so/,
                   /\Alibpthread\.so/, /\Alibdl\.so/, /\Alibrt\.so/].freeze

    def initialize(game_dir, out_dir, platforms:, mkxp_linux: nil, mkxp_windows: nil)
      @game_dir = File.expand_path(game_dir)
      @out_dir = File.expand_path(out_dir)
      @platforms = platforms
      @mkxp_linux = mkxp_linux && File.expand_path(mkxp_linux)
      @mkxp_windows = mkxp_windows && File.expand_path(mkxp_windows)
    end

    def run
      raise ArgumentError, "game not found: #{@game_dir}" unless Dir.exist?(@game_dir)
      raise ArgumentError, "no Data directory in #{@game_dir}" unless Dir.exist?(File.join(@game_dir, "Data"))
      raise ArgumentError, "output already exists: #{@out_dir}" if File.exist?(@out_dir)

      FileUtils.mkdir_p(@out_dir)
      @platforms.each { |platform| send("package_#{platform}") }
      @out_dir
    end

    private

    def package_linux
      dir = File.join(@out_dir, "linux")
      copy_game(dir)
      engine = @mkxp_linux || File.join("vendor", "mkxp-z", "build", "mkxp-z.x86_64")
      raise ArgumentError, "Linux mkxp-z not found: #{engine} (pass --mkxp-z-linux)" unless File.file?(engine)

      FileUtils.cp(engine, File.join(dir, "mkxp-z"))
      FileUtils.chmod(0o755, File.join(dir, "mkxp-z"))
      copy_libraries(engine, File.join(dir, "lib"))
      File.write(File.join(dir, "run.sh"), <<~SH)
        #!/bin/sh
        cd "$(dirname "$0")" || exit 1
        LD_LIBRARY_PATH="$PWD/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" exec ./mkxp-z "$@"
      SH
      FileUtils.chmod(0o755, File.join(dir, "run.sh"))
      write_readme(dir, "linux")
    end

    def package_windows
      dir = File.join(@out_dir, "windows")
      copy_game(dir)
      engine = @mkxp_windows || File.join("vendor", "mkxp-z-windows")
      engine = File.join(engine, "mkxp-z.x86_64.exe") if File.directory?(engine)
      unless File.file?(engine)
        raise ArgumentError,
              "Windows mkxp-z not found (pass --mkxp-z-windows DIR, " \
              "or run script/fetch-mkxp-z windows)"
      end

      win_dir = File.dirname(engine)
      FileUtils.cp(engine, File.join(dir, "mkxp-z.x86_64.exe"))
      %w[stdlib scripts LICENSE.txt].each do |name|
        source = File.join(win_dir, name)
        FileUtils.cp_r(source, File.join(dir, name)) if File.exist?(source)
      end
      File.write(File.join(dir, "run.bat"), <<~BAT)
        @echo off
        cd /d "%~dp0"
        mkxp-z.x86_64.exe %*
      BAT
      write_readme(dir, "windows")
    end

    def copy_game(dir)
      FileUtils.mkdir_p(dir)
      Dir.children(@game_dir).sort.each do |name|
        next if SKIP.include?(name)
        next if SKIP_PATTERNS.any? { |pattern| pattern.match?(name) }

        source = File.join(@game_dir, name)
        target = File.join(dir, name)
        if File.directory?(source)
          FileUtils.cp_r(source, target)
        else
          FileUtils.cp(source, target)
        end
      end
    end

    # The desktop build links against a few libraries that not every
    # distribution installs (OpenSSL, ffi, yaml, zstd); bundle them next to
    # the binary and make the launcher prefer them.
    def copy_libraries(engine, lib_dir)
      output = `ldd #{engine.shellescape}` rescue ""
      libs = output.lines.filter_map do |line|
        path = line[/=>\s+(\S+)/, 1]
        path if path && !SYSTEM_LIBS.any? { |pattern| pattern.match?(File.basename(path)) }
      end
      return if libs.empty?

      FileUtils.mkdir_p(lib_dir)
      libs.each { |path| FileUtils.cp(path, lib_dir) if File.file?(path) }
    end

    def write_readme(dir, platform)
      launcher = platform == "linux" ? "./run.sh" : "run.bat"
      File.write(File.join(dir, "README.txt"), <<~TEXT)
        #{File.basename(@game_dir)}

        Start the game with #{launcher}.

        This folder is self-contained: the game and the mkxp-z engine are
        included. The engine is free software under the GNU GPL v2 or later
        (see LICENSE.txt on Windows, and the mkxp-z project); the game data
        remains the property of its authors.
      TEXT
    end
  end
end
