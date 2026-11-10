# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: GPL-3.0-or-later

require "zlib"

module Rmxp
  # Scripts.rxdata is a Marshal array of [id, name, zlib_deflated_source].
  # Each script becomes one .rb file plus an entry in scripts.yml.
  module Scripts
    FILE = "Scripts.rxdata"
    MANIFEST = "scripts.yml"

    module_function


    def unpack(rxdata_path, out_dir)
      entries = Marshal.load(File.binread(rxdata_path))
      raise ArgumentError, "#{rxdata_path}: unexpected format" unless entries.is_a?(Array)

      Dir.mkdir(out_dir) unless Dir.exist?(out_dir)
      manifest = entries.each_with_index.map do |entry, index|
        id, name, compressed = entry
        source = Zlib::Inflate.inflate(compressed)
        file = format("%04d_%s.rb", index + 1, safe_name(name))
        File.binwrite(File.join(out_dir, file), source)
        entry_manifest(id, name, file)
      end
      verify_unpack(entries, manifest, out_dir)
      File.write(File.join(File.dirname(out_dir), MANIFEST), YAML.dump({ "scripts" => manifest }))
      manifest
    end

    def build(project_dir)
      manifest_path = File.join(project_dir, MANIFEST)
      raise ArgumentError, "scripts manifest not found: #{manifest_path}" unless File.file?(manifest_path)

      manifest = YAML.safe_load_file(manifest_path).fetch("scripts")
      entries = manifest.map do |entry|
        file = File.join(project_dir, "scripts", entry["file"])
        raise ArgumentError, "script not found: #{file}" unless File.file?(file)

        [entry["id"], entry_name(entry), Zlib::Deflate.deflate(File.binread(file))]
      end
      Marshal.dump(entries)
    end

    def entry_manifest(id, name, file)
      entry = { "id" => id, "file" => file }
      decoded = name.dup.force_encoding(Encoding::UTF_8)
      if decoded.valid_encoding?
        entry["name"] = decoded
      else
        entry["name_b64"] = Base64.strict_encode64(name)
        entry["name_enc"] = name.encoding.name
      end
      entry
    end

    def entry_name(entry)
      return entry["name"] if entry.key?("name")

      bytes = Base64.strict_decode64(entry.fetch("name_b64"))
      bytes.force_encoding(entry.fetch("name_enc", "ASCII-8BIT"))
    end

    def safe_name(name)
      decoded = name.dup.force_encoding(Encoding::UTF_8).scrub("_")
      decoded = decoded.gsub(/[^A-Za-z0-9_.\- ]/, "_").strip
      decoded.empty? ? "script" : decoded
    end

    # Unpacking is only trustworthy if the manifest rebuilds the same entries.
    def verify_unpack(entries, manifest, out_dir)
      entries.each_with_index do |(id, name, compressed), index|
        source = File.binread(File.join(out_dir, manifest[index]["file"]))
        original = Zlib::Inflate.inflate(compressed)
        next if source == original && id == manifest[index]["id"] && name == entry_name(manifest[index])

        raise ArgumentError, "script #{index + 1} does not read back identically"
      end
    end
  end
end
