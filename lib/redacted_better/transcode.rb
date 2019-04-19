require "fileutils"

class Transcode
  def self.file_is_24bit?(path)
    FlacInfo.new(path).streaminfo["bits_per_sample"] > 16
  end

  def self.file_is_multichannel?(path)
    FlacInfo.new(path).streaminfo["channels"] > 2
  end

  def self.transcode(torrent, format, encoding, fixed_24bit, spinner)
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
    flac_files = torrent.flacs
    errors = {}

    flac_files.each do |flac|
      flacinfo = FlacInfo.new(flac)

      required_sample_rate, sample_rate_errors = check_sample_rate(flacinfo)
      multichannel_errors = check_channels(flacinfo)

      errors[flac] = (sample_rate_errors + multichannel_errors).flatten
      next if errors[flac].any?

      # If we determined that we need to downsample, use SoX to do so
      if required_sample_rate
        downsampled_temp_dir = File.join(temp_dir, 'downsampled_files')
        FileUtils.mkdir_p(downsampled_temp_dir)
        new_flac = File.join(downsampled_temp_dir, File.basename(flac))
        sox_executable = $config.fetch(:executables, :sox) || 'sox'
        `#{sox_executable} #{flac} -qG -b 16 #{new_flac} -v -L #{required_sample_rate} dither`
      end

      case format
      when "FLAC"

      when "MP3"

      end
    end

    # Create final output directory and copy the finished transcode from the
    # temp directory into it
    output_dir = $config.fetch(:directories, :output)
    FileUtils.cp_r(File.join(temp_torrent_dir), output_dir)
  ensure
    FileUtils.remove_dir(temp_dir) if temp_dir
    FileUtils.remove_dir(torrent_dir) if torrent_dir
  end

  private

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
