# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# real: replaces the Windows gif.dll used by the community GifLibrary script.
# migrate converts every animated GIF to PNG frames and writes gif_frames.txt
# next to Data/. GifBitmap calls GifToPngFilesInMemory while the current
# directory is ENV["TEMP"], so copy the matching frames there under the names
# it opens.
#
# mkxp-z can load a GIF as one static bitmap, and Ruby 3's String#[0] returns a
# character instead of a byte, so the game would skip its own GIF code. The
# small patches below put converted GIFs back on that path.
if defined?(GifLibrary)
  module GifLibrary
    GIF_MANIFEST = "gif_frames.txt" unless const_defined?(:GIF_MANIFEST, false)
    GIF_GAME_ROOT = begin
      root = ENV["RMXP_GAME_ROOT"]
      if (root.nil? || root.empty?) && defined?(System) && System.respond_to?(:data_directory)
        root = System.data_directory
      end
      File.expand_path(root.nil? || root.empty? ? Dir.pwd : root)
    end unless const_defined?(:GIF_GAME_ROOT, false)

    class << self
      # real: gif.dll's GifToPngFilesInMemory. The frames were converted at
      # migration time; copy them to tmpBase + index + ".png" for GifBitmap.
      def gif_to_png_files_in_memory(_filestring, _length, tmp_base)
        entry = gif_frame_map[gif_manifest_key(tmp_base)]
        return 0 unless entry

        cleanup_gif_copies
        frames_dir, delays = entry
        frames_dir = File.join(GIF_GAME_ROOT, frames_dir)
        (delays.length - 1).times do |index|
          source = File.join(frames_dir, format("frame%04d.png", index))
          return 0 unless File.file?(source)
          name = "#{tmp_base}#{index}.png"
          data = File.binread(source)
          File.binwrite(name, data)
          # mkxp-z resolves Bitmap.new relative to the game root, not to the
          # current directory; keep a second copy for it and clean it later.
          if defined?(System)
            path = File.join(GIF_GAME_ROOT, name)
            File.binwrite(path, data)
            (@gif_game_copies ||= []) << path
          end
        end
        System.reload_cache if defined?(System) && System.respond_to?(:reload_cache)
        store_gif_result(delays)
      rescue SystemCallError
        0
      end

      def cleanup_gif_copies
        return unless @gif_game_copies
        @gif_game_copies.each { |path| File.delete(path) if File.file?(path) }
        @gif_game_copies = []
      end

      def delete_gif_game_copy(name)
        return unless @gif_game_copies && !@gif_game_copies.empty?
        path = File.join(GIF_GAME_ROOT, name)
        return unless @gif_game_copies.delete(path)
        File.delete(path) if File.file?(path)
      rescue SystemCallError
        nil
      end

      # real: gif.dll's CopyDataString + FreeDataString, packed into the method
      # GifBitmap already calls. Returns cumulative frame start times plus the
      # total duration, which GifBitmap pops as its loop length.
      def getDataFromResult(result)
        results = @gif_results
        results ? results.delete(result) : nil
      end

      def store_gif_result(delays)
        @gif_results ||= {}
        @gif_result_id = (@gif_result_id || 0) + 1
        @gif_results[@gif_result_id] = delays
        @gif_result_id
      end

      def gif_frame_map
        @gif_frame_map ||= begin
          map = {}
          path = File.join(GIF_GAME_ROOT, GIF_MANIFEST)
          if File.file?(path)
            File.foreach(path, chomp: true) do |line|
              next if line.empty? || line.start_with?("#")
              key, dir, units = line.split("\t", 3)
              next unless key && dir && units
              delays = units.split(",").map(&:to_i)
              next if delays.empty? || delays.any? { |delay| delay <= 0 }
              map[key] = [dir, gif_cumulative_delays(delays)]
            end
          end
          map
        end
      end

      # Manifest keys are the game's tmpBase (basename + "_tmp_") without the
      # .gif extension, so AnimatedBitmap.new("foo.gif") still matches.
      def gif_manifest_key(tmp_base)
        key = tmp_base.to_s
        return key if gif_frame_map.key?(key)
        key.sub(/\.gif(_tmp_)\z/i, '\1')
      end

      def converted_gif_path?(path)
        stem = File.basename(path.to_s).sub(/\.gif\z/i, "")
        return false unless gif_frame_stems.key?(stem)

        file = path.to_s
        file += ".gif" unless File.file?(file)
        File.file?(file) && File.binread(file, 4) == "GIF8"
      rescue SystemCallError
        false
      end

      def gif_frame_stems
        @gif_frame_stems ||= gif_frame_map.keys.each_with_object({}) do |key, stems|
          stems[key.sub(/_tmp_\z/, "")] = true
        end
      end

      attr_accessor :loading_gif_bitmap

      def gif_cumulative_delays(delays)
        total = 0
        cumulative = []
        delays.each do |delay|
          cumulative << total
          total += delay
        end
        cumulative << total
      end
    end

    remove_const(:PngDll) if const_defined?(:PngDll, false)
    PngDll = true

    remove_const(:GifToPngFilesInMemory) if const_defined?(:GifToPngFilesInMemory, false)
    GifToPngFilesInMemory = lambda do |filestring, length, tmp_base|
      gif_to_png_files_in_memory(filestring, length, tmp_base)
    end

    remove_const(:CopyDataString) if const_defined?(:CopyDataString, false)
    CopyDataString = lambda { |*_args| 0 }

    remove_const(:FreeDataString) if const_defined?(:FreeDataString, false)
    FreeDataString = lambda { |*_args| nil }
  end

  at_exit { GifLibrary.cleanup_gif_copies if defined?(GifLibrary) }

  # Ruby 1.8's String#[] returned a byte. GifBitmap still compares
  # filestring[0] with 0x47 ("G"), which is false with Ruby 3 strings and
  # leaves the GIF on the blank/static path.
  class GifByteString < String
    def [](*args)
      return getbyte(args[0]) if args.length == 1 && args[0].is_a?(Integer)
      super
    end
  end

  if defined?(GifBitmap) && Object.private_method_defined?(:pbGetFileString)
    class Object
      unless private_method_defined?(:__rmxp_gif_pb_get_file_string)
        alias_method :__rmxp_gif_pb_get_file_string, :pbGetFileString
      end
      if private_method_defined?(:pbGetFileChar) && !private_method_defined?(:__rmxp_gif_pb_get_file_char)
        alias_method :__rmxp_gif_pb_get_file_char, :pbGetFileChar
      end
      private

      def pbGetFileString(file)
        data = __rmxp_gif_pb_get_file_string(file)
        return data unless data && GifLibrary.converted_gif_path?(file)
        GifByteString.new(data)
      end

      if private_method_defined?(:__rmxp_gif_pb_get_file_char)
        def pbGetFileChar(file)
          char = __rmxp_gif_pb_get_file_char(file)
          return char unless char && char.length == 1 && GifLibrary.converted_gif_path?(file)
          GifByteString.new(char)
        end
      end
    end
  end

  # mkxp-z can decode a GIF as one static bitmap. GifBitmap then takes its
  # "regular bitmap" branch and never asks for frames. Reject only that first
  # lookup so the game reaches the replaced DLL calls.
  if defined?(GifBitmap) && defined?(BitmapCache)
    module GifBitmapFramePath
      def initialize(file, hue = 0)
        GifLibrary.loading_gif_bitmap = GifLibrary.converted_gif_path?(file)
        super
      ensure
        GifLibrary.loading_gif_bitmap = false
      end
    end
    GifBitmap.prepend(GifBitmapFramePath)

    class << BitmapCache
      alias_method :__rmxp_gif_frames_load_bitmap, :load_bitmap unless method_defined?(:__rmxp_gif_frames_load_bitmap)
      def load_bitmap(path, hue = 0, failsafe = false)
        if GifLibrary.loading_gif_bitmap && GifLibrary.converted_gif_path?(path)
          raise "converted GIF frames are loaded by GifLibrary"
        end
        __rmxp_gif_frames_load_bitmap(path, hue, failsafe)
      end
    end
  end

  # The game loads each copied frame through BitmapWrapper.new, then deletes
  # the copy in ENV["TEMP"]. Drop the game-root copy at the same time.
  if defined?(BitmapWrapper)
    module GifBitmapWrapperCleanup
      def initialize(*args)
        super
      ensure
        GifLibrary.delete_gif_game_copy(args[0]) if args.length == 1 && args[0].is_a?(String)
      end
    end
    BitmapWrapper.prepend(GifBitmapWrapperCleanup)
  end
end
