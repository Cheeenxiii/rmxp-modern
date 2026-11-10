# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "fileutils"
require "zlib"
require "yaml"

module Rmxp
  # A game directory <-> text project directory.
  #
  # Project layout:
  #   manifest.yml          game files, scripts and options
  #   data/<file>.yaml      one YAML file per Data/*.rxdata and Data/*.dat
  #   scripts/*.rb          one file per Scripts.rxdata entry
  #   scripts.yml           script order, ids and names
  #   scripts_tree/         optional external Scripts/ directory (Reborn)
  class Project
    FORMAT = 1
    DATA_PATTERN = /\.(rxdata|dat)\z/

    attr_reader :root

    def initialize(root)
      @root = root
    end

    def unpack(game_dir, out_dir)
      data_dir = File.join(game_dir, "Data")
      raise ArgumentError, "no Data directory in #{game_dir}" unless Dir.exist?(data_dir)

      FileUtils.rm_rf(out_dir)
      FileUtils.mkdir_p(File.join(out_dir, "data"))
      manifest = { "format" => FORMAT, "source" => File.basename(game_dir), "data" => [] }

      data_files(data_dir).each do |name|
        Codec.reset_stubs!
        raw = File.binread(File.join(data_dir, name))
        entry = begin
          if Codec.marshal?(raw)
            tree = Codec.dump_bytes(raw)
            # Byte equality is the goal but not always reachable (RMXP's Ruby
            # 1.8 printed floats differently from modern Ruby). What must hold
            # is that the text tree is a faithful, stable representation.
            stable = Codec.to_tree(Codec.from_tree(tree)) == tree
            raise ArgumentError, "#{name}: unstable text representation" unless stable

            File.write(File.join(out_dir, "data", "#{name}.yaml"), YAML.dump(tree))
            { "file" => name, "format" => "marshal" }
          else
            nil
          end
        rescue StandardError
          # Some game-specific Marshal data cannot be decoded without the
          # game's own classes. Keep the bytes verbatim: the build stays
          # faithful, the file is just not text (listed as "opaque").
          { "file" => name, "format" => "opaque" }
        end

        if entry.nil? || entry["format"] == "opaque"
          File.binwrite(File.join(out_dir, "data", "#{name}.bin"), raw)
          manifest["data"] << { "file" => name, "format" => "opaque" }
        else
          manifest["data"] << entry
        end
      end

      scripts_path = File.join(data_dir, Scripts::FILE)
      if File.file?(scripts_path)
        Scripts.unpack(scripts_path, File.join(out_dir, "scripts"))
        manifest["scripts"] = true
      end

      external_scripts = File.join(game_dir, "Scripts")
      if Dir.exist?(external_scripts)
        FileUtils.cp_r(external_scripts, File.join(out_dir, "scripts_tree"))
        manifest["scripts_tree"] = true
      end

      File.write(File.join(out_dir, "manifest.yml"), YAML.dump(manifest))
      manifest
    end

    def build(out_game_dir)
      manifest_path = File.join(root, "manifest.yml")
      raise ArgumentError, "manifest not found: #{manifest_path}" unless File.file?(manifest_path)

      manifest = YAML.safe_load_file(manifest_path)
      data_out = File.join(out_game_dir, "Data")
      FileUtils.mkdir_p(data_out)

      manifest.fetch("data").each do |entry|
        name = entry.fetch("file")
        if entry["format"] == "opaque"
          File.binwrite(File.join(data_out, name), File.binread(File.join(root, "data", "#{name}.bin")))
          next
        end

        Codec.reset_stubs!
        tree = YAML.safe_load_file(File.join(root, "data", "#{name}.yaml"))
        File.binwrite(File.join(data_out, name), Codec.load_tree_bytes(tree))
      end

      if manifest["scripts"]
        File.binwrite(File.join(data_out, Scripts::FILE), Scripts.build(root))
      end

      if manifest["scripts_tree"] && Dir.exist?(File.join(root, "scripts_tree"))
        FileUtils.cp_r(File.join(root, "scripts_tree"), File.join(out_game_dir, "Scripts"))
      end

      manifest
    end

    # Unpack + build + compare, without touching the game directory.
    # Returns a report hash; raises on the first inconsistency.
    def roundtrip(work_dir)
      game_dir = root
      unpack_dir = File.join(work_dir, "unpacked")
      rebuilt_dir = File.join(work_dir, "rebuilt")

      manifest = unpack(game_dir, unpack_dir)
      FileUtils.rm_rf(rebuilt_dir)
      Project.new(unpack_dir).build(rebuilt_dir)

      source_data = File.join(game_dir, "Data")
      rebuilt_data = File.join(rebuilt_dir, "Data")
      report = {
        "game" => File.basename(game_dir),
        "files" => manifest["data"].length,
        "byte_identical" => 0,
        "semantic_identical" => 0,
        "scripts" => manifest["scripts"] ? 1 : 0,
        "opaque" => manifest["data"].count { |entry| entry["format"] == "opaque" },
        "mismatches" => []
      }

      manifest.fetch("data").each do |entry|
        name = entry.fetch("file")
        original = File.binread(File.join(source_data, name))
        rebuilt = File.binread(File.join(rebuilt_data, name))
        if original == rebuilt
          report["byte_identical"] += 1
        elsif semantic_equal?(original, rebuilt)
          report["semantic_identical"] += 1
        else
          report["mismatches"] << name
        end
      end

      if manifest["scripts"]
        original = Marshal.load(File.binread(File.join(source_data, Scripts::FILE)))
        rebuilt = Marshal.load(File.binread(File.join(rebuilt_data, Scripts::FILE)))
        unless script_entries_equal?(original, rebuilt)
          report["mismatches"] << Scripts::FILE
          report["scripts"] = 0
        end
      end

      raise "#{report['game']}: files differ: #{report['mismatches'].join(', ')}" unless report["mismatches"].empty?

      report
    end

    private

    def data_files(data_dir)
      Dir.children(data_dir).sort.select do |name|
        name.match?(DATA_PATTERN) && name != Scripts::FILE
      end
    end

    def semantic_equal?(original, rebuilt)
      Codec.reset_stubs!
      left = Codec.dump_bytes(original)
      Codec.reset_stubs!
      left == Codec.dump_bytes(rebuilt)
    rescue StandardError
      false
    end

    def script_entries_equal?(original, rebuilt)
      return false unless original.length == rebuilt.length

      original.zip(rebuilt).all? do |left, right|
        left[0] == right[0] &&
          normalize_name(left[1]) == normalize_name(right[1]) &&
          Zlib::Inflate.inflate(left[2]) == Zlib::Inflate.inflate(right[2])
      end
    end

    def normalize_name(name)
      name.dup.force_encoding(Encoding::UTF_8).scrub("?")
    end
  end
end
