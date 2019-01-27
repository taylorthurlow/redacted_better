class Group
  attr_accessor :id, :name, :year, :record_label, :artists, :torrents

  def initialize(data_hash)
    @id = data_hash['id']
    @name = data_hash['name']
    @artists = data_hash['musicInfo']['artists']
    @year = data_hash['year']
    @record_label = data_hash['recordLabel']
    @torrents = []
  end

  def artist
    case @artists.count
    when 1
      @artists.first['name']
    when 2
      "#{@artists[0]['name']} & #{@artists[1]['name']}"
    else
      'Various Artists'
    end
  end

  # Given a torrent in a release group, find all torrents in the group which
  # are in the same release group. The returned list will also include the
  # torrent used to identify the release group.
  def release_group_torrents(torrent)
    torrents.select { |t| Torrent.in_same_release_group?(t, torrent) }
  end

  def formats_missing(torrent)
    present = release_group_torrents(torrent).map { |t| [t.format, t.encoding] }

    Torrent.formats_accepted
           .values
           .map(&:values)
           .reject { |f| present.include? f }
  end
end
