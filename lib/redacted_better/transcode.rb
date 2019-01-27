class Transcode
  def self.all_24bit?(files)
    files.select { |f| File.extname(f) == '.flac' }
         .all? { |f| File.exist?(f) && file_is_24bit?(f) }
  end

  def self.file_is_24bit?(file)
    FlacInfo.new(file).streaminfo['bits_per_sample'] > 16
  end

  def self.mislabeled_24bit?(files, encoding)
    all_24bit?(files) && encoding != '24bit Lossless'
  end

  def self.any_multichannel?(files)
    files.select { |f| File.extname(f) == '.flac' }
         .any? { |f| File.exist?(f) && file_is_multichannel?(f) }
  end

  def self.file_is_multichannel?(file)
    FlacInfo.new(file).streaminfo['channels'] > 2
  end
end
