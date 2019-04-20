require "fileutils"

class Transcode
  ENCODERS = {
    "320" => { enc: "lame", ext: "mp3", opts: "-h -b 320 --ignore-tag-errors" },
    "V0 (VBR)" => { enc: "lame", ext: "mp3", opts: "-V 0 --vbr-new --ignore-tag-errors" },
    "V2 (VBR)" => { enc: "lame", ext: "mp3", opts: "-V 2 --vbr-new --ignore-tag-errors" },
    "Lossless" => { enc: "flac", ext: "flac", opts: "--best" },
  }

  def self.file_is_24bit?(path)
    FlacInfo.new(path).streaminfo["bits_per_sample"] > 16
  end

  def self.file_is_multichannel?(path)
    FlacInfo.new(path).streaminfo["channels"] > 2
  end

  def self.transcode(torrent, format, encoding, spinner)
    # Determine the new torrent directory name
    format_shorthand = Torrent.build_format(format, encoding)
    torrent_name = Torrent.build_string(torrent.group.artist,
                                        torrent.group.name, torrent.year,
                                        torrent.media, format_shorthand)

    # Set up a temporary directory to work in
    temp_dir = Dir.mktmpdir
    temp_torrent_dir = File.join(temp_dir, torrent_name)
    FileUtils.mkdir_p(temp_torrent_dir)

    # Process each file
    torrent.flacs.each do |file_path|
      spinner.update(text: File.basename(file_path))
      new_file_name = "#{File.basename(file_path, ".*")}.#{format.downcase}"
      destination_file = File.join(temp_torrent_dir, new_file_name)
      exit_code, errors = transcode_file(format, encoding, file_path, destination_file)

      unless exit_code.zero?
        spinner.error("(transcode failed with exit code #{exit_code})")
        return
      end

      if errors.any?
        spinner.error(errors.join(", "))
        return
      end
    end

    # Create final output directory and copy the finished transcode from the
    # temp directory into it
    output_dir = $config.fetch(:directories, :output)
    FileUtils.cp_r(File.join(temp_torrent_dir), output_dir)

    spinner.update(text: "")
    spinner.success(" - done!")
  ensure
    FileUtils.remove_dir(temp_dir, true) if temp_dir
    FileUtils.remove_dir(temp_torrent_dir, true) if temp_torrent_dir
  end

  private

  # Transcode a single FLAC file to a specific destination
  def self.transcode_file(format, encoding, source, destination)
    # Check for any problems with the source file
    flacinfo = FlacInfo.new(source)
    required_sample_rate, sample_rate_errors = check_sample_rate(flacinfo)
    multichannel_errors = check_channels(flacinfo)
    errors = (sample_rate_errors + multichannel_errors).flatten

    cmds = transcode_commands(format, encoding, source, destination, required_sample_rate)
    `#{cmds.join(" | ")}`

    [$?.exitstatus, errors]
  end

  # Builds a list of steps required to transcode a FLAC into the specified
  # format, performing resampling if required
  def self.transcode_commands(format, encoding, source, destination, sample_rate)
    # Set up executable paths
    sox_exe = $config.fetch(:executables, :sox) || "sox"
    flac_exe = $config.fetch(:executables, :flac) || "flac"
    lame_exe = $config.fetch(:executables, :lame) || "lame"

    # If we're just resampling a FLAC to another FLAC, just use SoX to do that,
    # and skip the rest of the transcode process
    if format == "FLAC" && sample_rate
      return ["#{sox_exe} \"#{source}\" -qG -b 16 \"#{destination}\" rate -v -L #{sample_rate} dither"]
    end

    # If we determined that we need to downsample, use SoX to do so, otherwise
    # just decode to WAV
    flac_decoder = if sample_rate
                     "#{sox_exe} \"#{source}\" -qG -b 16 -t wav - rate -v -L #{sample_rate} dither"
                   else
                     # Decodes FLAC to WAV, writing to STDOUT
                     "#{flac_exe} -dcs -- \"#{source}\""
                   end

    transcode_steps = [flac_decoder]

    case ENCODERS[encoding][:enc]
    when "lame"
      transcode_steps << "#{lame_exe} --quiet #{ENCODERS[encoding][:opts]} - \"#{destination}\""
    when "flac"
      transcode_steps << "#{flac_exe} #{ENCODERS[encoding][:opts]} -o \"#{destination}\" -"
    end

    transcode_steps
  end

  # Determine if we need to resample the FLAC, this is so we ensure we only
  # have 44.1kHz or 48kHz output
  def self.check_sample_rate(flacinfo)
    errors = []

    sample_rate = flacinfo.streaminfo["samplerate"]
    bit_depth = flacinfo.streaminfo["bits_per_sample"]

    if sample_rate > 48000 || bit_depth > 16
      required_sample_rate = if sample_rate % 44100 == 0
                               44100
                             elsif sample_rate % 48000 == 0
                               4800
                             else
                               errors << "#{sample_rate}Hz sample rate unsupported"
                             end
    end

    [required_sample_rate, errors]
  end

  # Reject any files which have more than 2 channels, multichannel releases are
  # unsupported
  def self.check_channels(flacinfo)
    errors = []
    channels = flacinfo.streaminfo["channels"]

    if channels > 2
      errors << "Multichannel releases are unsupported - found #{channels}"
    end

    errors
  end
end
