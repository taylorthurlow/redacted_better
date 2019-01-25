class Transcode
  # Returns true if all files in the given directory are 24-bit files. It is
  # important to note that if any of the files in the directory are not 24-bit,
  # this method will return false. This happens sometimes, particularly with
  # Bandcamp releases.
  def self.directory_is_24bit?(directory)
    files = Find.find(directory).select { |f| File.file?(f) && f.end_with?('.flac') }
    files.all? { |f| file_is_24bit?(f) }
  end

  def self.file_is_24bit?(file)
    FlacInfo.new(file).streaminfo['bits_per_sample'] > 16
  end

  def self.directory_any_multichannel?(directory)
    files = Find.find(directory).select { |f| File.file?(f) && f.end_with?('.flac') }
    files.any? { |f| file_is_multichannel?(f) }
  end

  def self.file_is_multichannel?(file)
    FlacInfo.new(file).streaminfo['channels'] > 2
  end
end
