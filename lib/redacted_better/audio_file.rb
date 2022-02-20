require "fileutils"
require "mediainfo"
require "openssl"
require "pathname"

module RedactedBetter
  class AudioFile
    # @return [Array<String>] The list of substrings (typically single
    #   characters) that are forbidden in file paths.
    FORBIDDEN_SUBSTRINGS = %w[? : < > \\ * | " //].freeze

    # @return [Array<String>] valid mimetypes for audio files
    ALLOWED_MIMETYPES = %w[
      audio/mpeg
      audio/flac
    ].freeze

    # @return [Pathname] full file path to audio file
    attr_reader :path

    # @return [MediaInfo::Tracks]
    attr_reader :mediainfo

    # @return [Boolean]
    attr_reader :checked_for_errors

    # @param path [Pathname] full path to audio file
    # @param mediainfo [MediaInfo::Tracks, nil]
    def initialize(path, mediainfo = nil)
      @path = path
      @mediainfo = mediainfo || MediaInfo.from(path.to_s)
      @checked_for_errors = false
      @errors = []
    end

    # @return [Boolean]
    def checked_for_errors?
      checked_for_errors
    end

    # Problems which would prevent processing or uploading.
    #
    # @return [Array<String>]
    def errors
      raise "This audio file has not been checked for errors yet." unless checked_for_errors?

      @errors
    end

    # @return [String, nil] the full local file path to the spectrogram PNG, or
    #   nil if the process failed
    def spectrogram
      name = path.basename

      file = File.open(@path)
      md5 = OpenSSL::Digest::MD5.file(file)
      out_path = File.join(Dir.tmpdir, "#{md5}-spectrogram.png")

      if File.exist?(out_path)
        out_path
      else
        `sox "#{@path}" -n remix 1 spectrogram -x 1500 -y 500 -z 120 -w Kaiser -t "#{name}" -o "#{out_path}"`

        out_path if $?.success?
      end
    rescue Interrupt
      FileUtils.rm(out_path) if out_path && File.exist?(out_path)

      raise
    ensure
      file&.close
    end

    # Rules about uploads:
    # - FLAC maximum 24-bit, 192 kHz, minimum 16-bit, 44.1 kHz
    # - Inconsistent bit rate must include release description with note about
    #   which tracks have which bit rate
    # - Lossy formats allowed: MP3, AAC, AC3, DTS
    # - Lossless formats allowed: FLAC

    # Bit depth in bits. Not expected to be present on lossy formats, as they do
    # not have a fixed bit depth.
    #
    # @return [Integer, nil]
    def bit_depth
      mediainfo.audio.bitdepth
    end

    # The bit rate in bits per second. Expected to be set for all formats. In
    # the case of VBR files, this will be the average bit rate.
    #
    # @return [Integer, nil]
    def bit_rate
      mediainfo.audio.bitrate
    end

    # The bit rate/encoding mode, expected to be "VBR" or "CBR", corresponding
    # to Variable and Constant Bit Rate, respectively. Expected to be set for
    # all formats.
    #
    # @return [String, nil]
    def bit_rate_mode
      mediainfo.audio.bit_rate_mode
    end

    # The sample rate in hertz (i.e. 44.1 kHz == 44100). Expected to be set for
    # all formats.
    #
    # @return [Integer, nil]
    def sample_rate
      mediainfo.audio.samplingrate
    end

    # The compression mode (`Lossless`, or `Lossy`). Expected to be set for all
    # formats.
    #
    # @return [String, nil]
    def compression_mode
      mediainfo.audio.compression_mode
    end

    # The number of audio channels. Expected to be set for all formats.
    #
    # @return [Integer, nil]
    def channels
      mediainfo.audio.channels
    end

    # The audio format, including the format "profile" if also reported (i.e.
    # `FLAC`, `MPEG Audio Layer 3`). Expected to be set for all formats.
    #
    # @return [String, nil]
    def format
      string = "#{mediainfo.audio.format} #{mediainfo.audio.format_profile}".strip

      return nil if string.empty?

      string
    end

    # @return [String, nil]
    def artist
      mediainfo.general.performer || mediainfo.general.album_performer
    end

    # @return [String, nil]
    def album
      mediainfo.general.album
    end

    # @return [String, nil]
    def title
      mediainfo.general.title || mediainfo.general.track
    end

    # @return [String, nil]
    def track_number
      mediainfo.general.track_position
    end

    # @return [String, nil]
    def date
      mediainfo.general.recorded_date&.to_s
    end

    # @return [String, nil]
    def label
      mediainfo.general.label&.to_s
    end

    # @!method bit_rate!
    #   @return [Integer]

    # @!method bit_depth!
    #   @return [Integer]

    # @!method bit_rate_mode!
    #   @return [String]

    # @!method sample_rate!
    #   @return [Integer]

    # @!method compression_mode!
    #   @return [String]

    # @!method channels!
    #   @return [Integer]

    # @!method format!
    #   @return [String]

    # @!method artist!
    #   @return [String]

    # @!method album!
    #   @return [String]

    # @!method title!
    #   @return [String]

    # @!method track_number!
    #   @return [String]

    # @!method date!
    #   @return [String]

    # @!method label!
    #   @return [String]

    # Generate bang! accessors for certain mediainfo attributes that will raise
    # an exception if they return a nil value.

    %i[
      bit_depth
      bit_rate
      bit_rate_mode
      sample_rate
      compression_mode
      channels
      format
      artist
      album
      title
      track_number
      date
      label
    ].each do |method|
      define_method("#{method}!".to_sym) do
        result = self.send(method)

        return result if result

        raise MissingAudioMetadataError.new(method)
      end
    end

    class MissingAudioMetadataError < StandardError
      # @param missing_attribute_name [Symbol]
      def initialize(missing_attribute_name)
        super "File at path \"#{path}\" unable to determine media attribute: #{missing_attribute_name}"
      end
    end

    # Check the file and its path for errors and add any errors to the `errors` attribute.
    #
    # @return [Array<String>]
    def check_for_errors
      @errors += Tags.tag_errors(path)

      # Check for invalid filenames
      if (whitespace_led_component = Pathname(path).each_filename.to_a.find { |p| p.start_with?(/\s+/) })
        @errors << "path contains a file or directory name with leading whitespace: #{whitespace_led_component}"
      end

      if (forbidden_substrings = FORBIDDEN_SUBSTRINGS.select { |fss| path.to_s.include?(fss) }).any?
        @errors << "path contains invalid character(s): #{forbidden_substrings.join(" ")}"
      end

      if format == "FLAC"
        _stdout, stderr, status = Open3.capture3("flac -wt \"#{path}\"")

        unless status.success?
          error_line = stderr.split("\n")
                             .find { |line| line.include?(File.basename(path)) }

          @errors << if error_line
            "failed flac verification test: #{error_line}"
          else
            "failed flac verification test"
          end
        end
      end

      if (bit_depth && ![16, 24].include?(bit_depth))
        @errors << "#{bit_depth} is an invalid bit depth"
      elsif !bit_depth && format == "FLAC"
        @errors << "unable to determine bit depth"
      end

      if sample_rate.nil?
        @errors << "unable to determine sample rate"
      else
        case bit_depth
        when 16
          unless [44_100, 48_000].include?(sample_rate)
            sample_rate_khz = sample_rate.to_f / 100
            @errors << "#{sample_rate_khz} kHz is not a valid sample rate for a 16-bit lossless file"
          end
        when 24
          unless [44_100, 88_200, 176_400, 352_800, 48_000, 96_000, 192_000, 384_000].include?(sample_rate)
            sample_rate_khz = sample_rate.to_f / 100
            @errors << "#{sample_rate_khz} kHz is not a valid sample rate for a 24-bit lossless file"
          end
        when nil # will happen for Lossy formats
          unless [44_100, 48_000].include?(sample_rate)
            sample_rate_khz = sample_rate.to_f / 100
            @errors << "#{sample_rate_khz} kHz is not a valid sample rate for a lossy file format"
          end
        end
      end

      @checked_for_errors = true

      @errors
    end
  end
end
