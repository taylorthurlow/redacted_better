class Utils
  def self.find_flac_recursively(directory)
    Find.find(directory).select do |f|
      File.file?(f) && File.extname(f) == '.flac'
    end
  end

  def self.format_torrent_name(artist, release, year, media, format, encoding)
    format_str = format_shorthand(format, encoding)
    "#{artist} - #{release} (#{year}) [#{media} #{format_str}]"
  end

  def self.release_info_string(group, torrent)
    artists = group['musicInfo']['artists']
    artist = case artists.count
             when 1
               artists.first['name']
             when 2
               "#{artists[0]['name']} & #{artists[1]['name']}"
             else
               'Various Artists'
             end
    year = if torrent['remastered'] && !torrent['remasterYear'].zero?
             torrent['remasterYear']
           else
             group['year']
           end

    format_torrent_name(artist,
                        group['name'],
                        year,
                        torrent['media'],
                        torrent['format'],
                        torrent['encoding'])
  end

  def self.format_shorthand(format, encoding)
    case format
    when 'FLAC'
      encoding.include?('24') ? 'FLAC24' : 'FLAC'
    when 'MP3'
      case encoding
      when '320'
        '320'
      when 'V0 (VBR)'
        'MP3v0'
      when 'V2 (VBR)'
        'MP3v2'
      end
    end
  end
end
