require "mediainfo"

module RedactedBetter
  class AudioFile
    # @return [String] full file path to audio file
    attr_reader :path

    # @return [MediaInfo::Tracks]
    attr_reader :mediainfo

    # @param path [String] full path to audio file
    # @param mediainfo [MediaInfo::Tracks, nil]
    def initialize(path, mediainfo = nil)
      @path = path
      @mediainfo = mediainfo || MediaInfo.from(path)
    end

    # @return [Array<String>]
    def problems_preventing_upload
      errors = []

      errors += Tags.tag_errors(path)

      if (bit_depth && ![16, 24].include?(bit_depth))
        errors << "#{bit_depth} is an invalid bit depth"
      elsif !bit_depth && format == "FLAC"
        errors << "unable to determine bit depth"
      end

      if sample_rate.nil?
        errors << "unable to determine sample rate"
      else
        case bit_depth
        when 16
          unless [44_100, 48_000].include?(sample_rate)
            sample_rate_khz = sample_rate.to_f / 100
            errors << "#{sample_rate_khz} kHz is not a valid sample rate for a 16-bit lossless file"
          end
        when 24
          unless [44_100, 88_200, 176_400, 352_800, 48_000, 96_000, 192_000, 384_000].include?(sample_rate)
            sample_rate_khz = sample_rate.to_f / 100
            errors << "#{sample_rate_khz} kHz is not a valid sample rate for a 24-bit lossless file"
          end
        when nil # will happen for Lossy formats
          unless [44_100, 48_000].include?(sample_rate)
            sample_rate_khz = sample_rate.to_f / 100
            errors << "#{sample_rate_khz} kHz is not a valid sample rate for a lossy file format"
          end
        end
      end

      errors
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
      mediainfo.general.recorded_date.to_s
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
  end
end
