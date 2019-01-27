class Transcode
  def self.file_is_24bit?(path)
    FlacInfo.new(path).streaminfo['bits_per_sample'] > 16
  end

  def self.file_is_multichannel?(path)
    FlacInfo.new(path).streaminfo['channels'] > 2
  end
end
