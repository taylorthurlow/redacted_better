require "fileutils"
require "os"

module RedactedBetter
  # A class representing the transcode/conversion of a single audio file into
  # another audio file.
  class Transcode
    ENCODERS = {
      "320" => { enc: "lame", ext: "mp3", opts: "-h -b 320 --ignore-tag-errors" },
      "V0 (VBR)" => { enc: "lame", ext: "mp3", opts: "-V 0 --vbr-new --ignore-tag-errors" },
      "V2 (VBR)" => { enc: "lame", ext: "mp3", opts: "-V 2 --vbr-new --ignore-tag-errors" },
      "Lossless" => { enc: "flac", ext: "flac", opts: "--best" },
    }.freeze

    # @return [String]
    attr_accessor :format

    # @return [String]
    attr_accessor :encoding

    # @return [String]
    attr_accessor :source

    # @return [String]
    attr_accessor :destination

    # @return [Array<String>]
    attr_accessor :errors

    # @return [Integer, nil] sample rate in hertz (48kHz == 48_000Hz), or nil if
    #   the source does not have a compatible sample rate
    attr_accessor :target_sample_rate

    # @param format [String]
    # @param encoding [String]
    # @param source [String]
    # @param destination [String]
    def initialize(format, encoding, source, destination)
      @format = format
      @encoding = encoding
      @source = source
      @destination = destination

      # TODO: Use flac -t to test output flacs

      @errors = []

      # Validate bit depth
      source_bit_depth = flac_info.streaminfo["bits_per_sample"]
      @errors << "Invalid source bit depth: #{source_bit_depth}" unless [16, 24].include?(source_bit_depth)

      # Validate number of audio channels
      source_num_channels = flac_info.streaminfo["channels"]
      @errors << "Invalid source number of channels: #{source_num_channels}" if source_num_channels > 2

      # Determine target sample rate
      @target_sample_rate = begin
          source_sample_rate = flac_info.streaminfo["samplerate"]

          if source_sample_rate % 48_000
            48_000
          elsif source_sample_rate % 44_100
            44_100
          else
            @errors << "Unable to determine appropriate new sample rate for source rate: #{source_sample_rate}"

            nil
          end
        end
    end

    # Transcode the file to the specified destination.
    #
    # @return [Boolean] True if successful, false otherwise. View any propagated
    #   errors with the `error` attribute accessor.
    def process
      raise "Cannot process transcode with errors present." if errors.any?

      _stdout, _stderr, status = Open3.capture3(command_list.join(" | "))

      @errors << "Transcode pipeline exited with non-zero code: #{status.exitstatus}" unless status.success?
      @errors += Tags.copy_tags(source, destination)
      @errors += normalize_unicode(destination) if OS.mac?

      destination if @errors.none?
    end

    # Builds a list of steps required to transcode a FLAC into the specified
    # format, performing resampling if required
    #
    # @return [Array<String>]
    def command_list
      raise "Cannot build command list with errors present." if errors.any?

      @command_list ||= begin
          # If we're just resampling a FLAC to another FLAC, just use SoX to do
          # that, and skip the rest of the transcode process
          if format == "FLAC" && resampling_required?
            ["sox \"#{source}\" -qG -b 16 \"#{destination}\" rate -v -L #{target_sample_rate} dither"]
          else
            flac_decoder = if rescaling_required? || resampling_required?
                "sox \"#{source}\" -qG -b 16 -t wav - rate -v -L #{target_sample_rate} dither"
              else
                "flac -dcs -- \"#{source}\""
              end

            transcode_steps = [flac_decoder]

            transcode_steps << case ENCODERS[encoding][:enc]
            when "lame"
              "lame --quiet #{ENCODERS[encoding][:opts]} - \"#{destination}\""
            when "flac"
              "flac -s #{ENCODERS[encoding][:opts]} -o \"#{destination}\" -"
            end

            transcode_steps
          end
        end
    end

    # @return [Boolean]
    def file_is_24bit?
      flac_info.streaminfo["bits_per_sample"] > 16
    end

    # @return [Boolean]
    def file_is_multichannel?
      flac_info.streaminfo["channels"] > 2
    end

    # @return [Boolean]
    def self.file_is_24bit?(file)
      FlacInfo.new(file).streaminfo["bits_per_sample"] > 16
    end

    # @return [Boolean]
    def self.file_is_multichannel?(file)
      FlacInfo.new(file).streaminfo["channels"] > 2
    end

    private

    # Normalize the filename of a given file to Unicode NFC normalization
    # format. This is typically only required on macOS which sometimes generates
    # a different normalized Unicode string which is valid, but not typically
    # interoperable with torrent clients running on Linux.
    #
    # @param file_path [String]
    #
    # @return [Array<String>] errors, if any
    def normalize_unicode(file_path)
      `command -v convmv`
      return ["Could not find `convmv` command, required on macOS."] unless $?.success?

      _stdout, _stderr, status = Open3.capture3(
        "convmv -f UTF-8 -t UTF-8 --nfc --notest \"#{file_path}\"",
      )

      return ["Transcode pipeline exited with non-zero code: #{status.exitstatus}"] unless status.success?

      []
    end

    # @return [FlacInfo]
    def flac_info
      @flac_info ||= FlacInfo.new(source)
    end

    # Determine if the track needs to be resampled from a higher bit rate (like
    # 96kHz or 88.2kHz) to a lower bit rate (like 48kHz or 44.1kHz) during the
    # transcoding process.
    #
    # @return [Boolean]
    def resampling_required?
      flac_info.streaminfo["samplerate"] != target_sample_rate
    end

    # Determine if the track needs to be rescaled from 24-bit to 16-bit depth
    # during the transcoding process.
    #
    # @return [Boolean]
    def rescaling_required?
      flac_info.streaminfo["bits_per_sample"] != 16
    end
  end
end
