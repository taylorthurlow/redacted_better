require "fileutils"

module RedactedBetter
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

    # @param format [String]
    # @param encoding [String]
    # @param source [String]
    # @param destination [String]
    def initialize(format, encoding, source, destination)
      @format = format
      @encoding = encoding
      @source = source
      @destination = destination
    end

    # Transcode the file.
    #
    # @return [Hash]
    def process
      # Check for any problems with the source file
      resample_required, required_sample_rate, sample_rate_errors = check_sample_rate
      errors = sample_rate_errors.flatten

      # Get the list of commands which are piped together to get the final file
      cmds = command_list(resample_required, required_sample_rate)
      `#{cmds.join(" | ")}` if errors.none?

      if errors.none?
        # Copy the tags from the old file to the new file
        tags_success = Tags.copy_tags(source, destination)
        errors << "Error copying tags for #{File.basename(source)}." unless tags_success
      end

      {
        exit_code: $?.exitstatus,
        errors: errors,
      }
    end

    # Builds a list of steps required to transcode a FLAC into the specified
    # format, performing resampling if required
    #
    # @param resample_required [Boolean]
    # @param sample_rate [Integer]
    #
    # @return [Array<String>]
    def command_list(resample_required, sample_rate)
      # TODO: Allow configuration
      sox_exe = "sox"
      flac_exe = "flac"
      lame_exe = "lame"
      # sox_exe = $config.fetch(:executables, :sox) || "sox"
      # flac_exe = $config.fetch(:executables, :flac) || "flac"
      # lame_exe = $config.fetch(:executables, :lame) || "lame"

      # If we're just resampling a FLAC to another FLAC, just use SoX to do
      # that, and skip the rest of the transcode process
      if format == "FLAC" && resample_required
        return ["#{sox_exe} \"#{source}\" -qG -b 16 \"#{destination}\" rate -v -L #{sample_rate} dither"]
      end

      # If we determined that we need to downsample, use SoX to do so, otherwise
      # just decode to WAV
      flac_decoder = if resample_required
          "#{sox_exe} \"#{source}\" -qG -b 16 -t wav - rate -v -L #{sample_rate} dither"
        else
          # Decodes FLAC to WAV, writing to STDOUT
          "#{flac_exe} -dcs -- \"#{source}\""
        end

      transcode_steps = [flac_decoder]

      transcode_steps << case ENCODERS[encoding][:enc]
      when "lame"
        "#{lame_exe} --quiet #{ENCODERS[encoding][:opts]} - \"#{destination}\""
      when "flac"
        "#{flac_exe} -s #{ENCODERS[encoding][:opts]} -o \"#{destination}\" -"
      end

      transcode_steps
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

    # @return [String] the generated torrent's output directory
    def self.transcode(torrent, format, encoding, output_directory, spinner = nil)
      # Determine the new torrent directory name
      format_shorthand = Torrent.build_format(format, encoding)
      torrent_name = Torrent.build_string(torrent.group.artist,
                                          torrent.group.name, torrent.year,
                                          torrent.media, format_shorthand)

      # Get final output dir and make sure it doesn't already exist
      torrent_dir = File.join(output_directory, torrent_name)

      if Dir.exist?(torrent_dir)
        spinner&.update(text: " - Failed")
        spinner&.error(Pastel.new.red("(output directory exists)"))

        return false
      end

      # Set up a temporary directory to work in
      temp_dir = Dir.mktmpdir
      temp_torrent_dir = File.join(temp_dir, torrent_name)
      FileUtils.mkdir_p(temp_torrent_dir)

      # Process each file
      torrent.flac_files.each do |file_path|
        spinner&.update(text: " - " + File.basename(file_path))
        new_file_name = "#{File.basename(file_path, ".*")}.#{format.downcase}"
        destination_file = File.join(temp_torrent_dir, new_file_name)

        result = Transcode.new(format, encoding, file_path, destination_file).process

        unless result[:exit_code].zero?
          spinner&.error(Pastel.new.red("(transcode failed with exit code #{result[:exit_code]})"))

          return false
        end

        if result[:errors].any?
          spinner&.error(result[:errors].join(", "))

          return false
        end
      end

      # Create final output directory and copy the finished transcode from the
      # temp directory into it
      FileUtils.cp_r(File.join(temp_torrent_dir), output_directory)

      spinner&.update(text: "")

      torrent_dir
    ensure
      FileUtils.remove_dir(temp_dir, true) if temp_dir
      FileUtils.remove_dir(temp_torrent_dir, true) if temp_torrent_dir
    end

    private

    # @return [FlacInfo]
    def flac_info
      @flac_info ||= FlacInfo.new(source)
    end

    # Determine if we need to resample the FLAC, this is so we ensure we only
    # have 44.1kHz or 48kHz output
    def check_sample_rate
      errors = []

      sample_rate = flac_info.streaminfo["samplerate"]
      bit_depth = flac_info.streaminfo["bits_per_sample"]

      if (resample_required = sample_rate > 48_000 || bit_depth > 16)
        required_sample_rate = if (sample_rate % 44_100).zero?
            44_100
          elsif (sample_rate % 48_000).zero?
            48_000
          else
            errors << "#{sample_rate}Hz sample rate unsupported"
          end
      end

      [resample_required, required_sample_rate, errors]
    end
  end
end
