class SnatchParser
  def initialize(user_id:, cookie:, skip_ids: [])
    @user_id = user_id
    @cookie = cookie
    @skip_ids = skip_ids
  end

  def all
    finished = false
    parse_regex = /torrents\.php\?id=(\d+)&amp;torrentid=(\d+)/
    result = []

    until finished
      page = 1
      url = "torrents.php?type=snatched&userid=#{@user_id}&format=FLAC&page=#{page}"
      response = Faraday.new(url: 'https://redacted.ch/').get do |request|
        request.url url
        request.headers = { 'Cookie' => @cookie }
      end

      response.body.scan(parse_regex) do |group_id, torrent_id|
        next if @skip_ids.include? torrent_id.to_i

        result << { group_id: group_id.to_i, torrent_id: torrent_id.to_i }
      end

      finished = !response.body.include?('Next &gt;')
      page += 1
    end

    result
  end
end
