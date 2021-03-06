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

  def self.transcode(torrent, format, encoding, spinner = nil)
    # Determine the new torrent directory name
    format_shorthand = Torrent.build_format(format, encoding)
    torrent_name = Torrent.build_string(torrent.group.artist,
                                        torrent.group.name, torrent.year,
                                        torrent.media, format_shorthand)

    # Get final output dir and make sure it doesn't already exist
    output_dir = $config.fetch(:directories, :output)
    torrent_dir = File.join(output_dir, torrent_name)
    if Dir.exist? torrent_dir
      spinner&.update(text: " - Failed")
      spinner&.error(Pastel.new.red("(output directory exists)"))
      return false
    end

    # Set up a temporary directory to work in
    temp_dir = Dir.mktmpdir
    temp_torrent_dir = File.join(temp_dir, torrent_name)
    FileUtils.mkdir_p(temp_torrent_dir)

    # Process each file
    torrent.flacs.each do |file_path|
      spinner&.update(text: " - " + File.basename(file_path))
      new_file_name = "#{File.basename(file_path, ".*")}.#{format.downcase}"
      destination_file = File.join(temp_torrent_dir, new_file_name)
      exit_code, errors = transcode_file(format, encoding, file_path, destination_file)

      unless exit_code.zero?
        spinner&.error(Pastel.new.red("(transcode failed with exit code #{exit_code})"))
        return false
      end

      if errors.any?
        spinner&.error(errors.join(", "))
        return false
      end
    end

    # Create final output directory and copy the finished transcode from the
    # temp directory into it
    FileUtils.cp_r(File.join(temp_torrent_dir), output_dir)

    spinner&.update(text: "")
    spinner&.success(" - done!")

    torrent_dir
  ensure
    FileUtils.remove_dir(temp_dir, true) if temp_dir
    FileUtils.remove_dir(temp_torrent_dir, true) if temp_torrent_dir
  end

  # Transcode a single FLAC file to a specific destination
  def self.transcode_file(format, encoding, source, destination)
    # Check for any problems with the source file
    flacinfo = FlacInfo.new(source)
    resample_required, required_sample_rate, sample_rate_errors = check_sample_rate(flacinfo)
    multichannel_errors = check_channels(flacinfo)
    errors = (sample_rate_errors + multichannel_errors).flatten

    # Get the list of commands which are piped together to get the final file
    cmds = transcode_commands(format, encoding, source, destination, resample_required, required_sample_rate)
    `#{cmds.join(" | ")}` unless errors.any?

    unless errors
      # Copy the tags from the old file to the new file
      tags_success = Tags.copy_tags(source, destination)
      errors << "Error copying tags for #{File.basename(source)}." unless tags_success
    end

    [$?.exitstatus, errors]
  end

  private

  # Builds a list of steps required to transcode a FLAC into the specified
  # format, performing resampling if required
  def self.transcode_commands(format, encoding, source, destination, resample_required, sample_rate)
    # Set up executable paths
    sox_exe = $config.fetch(:executables, :sox) || "sox"
    flac_exe = $config.fetch(:executables, :flac) || "flac"
    lame_exe = $config.fetch(:executables, :lame) || "lame"

    # If we're just resampling a FLAC to another FLAC, just use SoX to do that,
    # and skip the rest of the transcode process
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

    resample_required = sample_rate > 48_000 || bit_depth > 16
    if resample_required
      required_sample_rate = if sample_rate % 44_100 == 0
                               44_100
                             elsif sample_rate % 48_000 == 0
                               48_000
                             else
                               errors << "#{sample_rate}Hz sample rate unsupported"
                             end
    end

    [resample_required, required_sample_rate, errors]
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
