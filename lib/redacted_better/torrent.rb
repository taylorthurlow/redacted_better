class Torrent
  attr_accessor :id, :media, :format, :encoding, :remastered, :remaster_year,
                :remaster_title, :remaster_record_label, :remaster_catalogue_number,
                :file_list, :file_path, :group

  def initialize(data_hash, group)
    @group = group
    @id = data_hash['id']
    @media = data_hash['media']
    @format = data_hash['format']
    @encoding = data_hash['encoding']
    @remastered = data_hash['remastered']
    @remaster_year = data_hash['remasterYear']
    @remaster_title = data_hash['remasterTitle']
    @remaster_record_label = data_hash['remasterRecordLabel']
    @remaster_catalogue_number = data_hash['remasterCatalogueNumber']
    @file_path = data_hash['filePath']
    @file_list = Torrent.parse_file_list(data_hash['fileList'],
                                         data_hash['filePath'])
  end

  def properly_contained?
    !@file_path.empty?
  end

  def on_disk?(flacs_only: false)
    @file_list.all? do |f|
      File.exist?(f) || (flacs_only && !File.extname(f).casecmp('.flac').zero?)
    end
  end

  def flacs
    @file_list.select { |f| File.extname(f).casecmp('.flac').zero? }
  end

  def all_24bit?
    on_disk?(flacs_only: true) && flacs.all? { |f| Transcode.file_is_24bit?(f) }
  end

  def mislabeled_24bit?
    all_24bit? && @encoding != '24bit Lossless'
  end

  def any_multichannel?
    on_disk?(flacs_only: true) && flacs.any? { |f| Transcode.file_is_multichannel?(f) }
  end

  def year
    if @remastered && !@remaster_year.zero?
      @remaster_year
    else
      @group.year
    end
  end

  def to_s
    "#{@group.artist} - #{@group.name} (#{year}) [#{@media} #{format_shorthand}]"
  end

  def url
    "https://redacted.ch/torrents.php?id=#{@group.id}&torrentid=#{@id}"
  end

  def missing_files
    @file_list.reject { |f| File.exist?(f) }
              .map { |f| File.basename(f) }
  end

  def check_valid_tags
    results = flacs.map { |f| Tags.valid_tags?(f) }

    {
      valid: results.all? { |r| r[:valid] },
      errors: results.map { |r| r[:errors] }.flatten
    }
  end

  def format_shorthand
    case @format
    when 'FLAC'
      @encoding.include?('24') ? 'FLAC24' : 'FLAC'
    when 'MP3'
      case @encoding
      when '320'
        '320'
      when 'V0 (VBR)'
        'MP3v0'
      when 'V2 (VBR)'
        'MP3v2'
      end
    end
  end

  def self.parse_file_list(raw_list, root_path)
    path = File.join($config.fetch(:directories, :download), root_path)
    raw_list.gsub(/\|\|\|/, '')
            .split(/\{\{\{\d+\}\}\}/)
            .map { |p| File.join(path, p) }
  end

  def self.in_same_release_group?(t1, t2)
    t1.media == t2.media &&
      t1.remaster_year == t2.remaster_year &&
      t1.remaster_title == t2.remaster_title &&
      t1.remaster_record_label == t2.remaster_record_label &&
      t1.remaster_catalogue_number == t2.remaster_catalogue_number
  end

  def self.formats_accepted
    {
      'FLAC' => { format: 'FLAC', encoding: 'Lossless' },
      '320' => { format: 'MP3', encoding: '320' },
      'V0' => { format: 'MP3', encoding: 'V0 (VBR)' }
      # 'V2' => { format: 'MP3', encoding: 'V2 (VBR)' }
    }
  end
end
