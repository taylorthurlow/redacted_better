class RedactedAPI
  def initialize(user_id:, cookie:, skip_ids: [])
    @user_id = user_id
    @cookie = cookie
    @skip_ids = skip_ids
  end

  def all_snatches
    finished = false
    parse_regex = /torrents\.php\?id=(\d+)&amp;torrentid=(\d+)/
    result = []

    spinner = TTY::Spinner.new('[:spinner] Loading snatches...', format: :dots_4)
    spinner.auto_spin

    until finished
      page = 1
      url = "torrents.php?type=snatched&userid=#{@user_id}&format=FLAC&page=#{page}"

      Request.wait_for_request

      response = Faraday.new(url: 'https://redacted.ch/').get do |request|
        request.url url
        request.headers = Request.headers('cookie' => @cookie)
      end

      Request.notify_request_sent

      response.body.scan(parse_regex) do |group_id, torrent_id|
        next if @skip_ids.include? torrent_id.to_i

        result << { group_id: group_id.to_i, torrent_id: torrent_id.to_i }
      end

      finished = !response.body.include?('Next &gt;')
      page += 1
    end

    spinner.stop(Pastel.new.green('done!'))

    result
  end

  def set_torrent_24bit(torrent_id)
    spinner = TTY::Spinner.new('  [:spinner] Fixing mislabeled 24-bit torrent...', format: :dots_4)
    spinner.auto_spin

    agent = Mechanize.new
    page = agent.get("https://redacted.ch/torrents.php?action=edit&id=#{torrent_id}", [], nil, 'Cookie' => @cookie)
    form = page.form('torrent')
    form.field_with(name: 'bitrate').option_with(value: '24bit Lossless').click
    page = agent.submit(form, form.button_with(value: 'Edit torrent'), 'Cookie' => @cookie)

    if page.code.to_i == 200
      spinner.stop(Pastel.new.green('done!'))
      true
    else
      spinner.stop(Pastel.new.red('failed.'))
      false
    end
  end

  def info_by_group_id(group_id)
    response = Request.send_request(
      action: 'torrentgroup',
      cookie: @cookie,
      params: { id: group_id }
    )

    if response[:status] == 'success'
      deep_unescape_html(response[:response])
    else
      Log.error("Failed to get info for torrent group #{group_id}.")
      false
    end
  end

  def formats_missing(group, torrent, all_torrents)
    group_torrents = all_torrents.select do |t|
      RedactedAPI.torrents_in_same_group?(t, torrent)
    end
    Log.info("  Found #{group_torrents.count} in group: ", newline: false)
    present = group_torrents.map { |t| [t['format'], t['encoding']] }
    Log.info(present.map { |f| f.join(' ') }.join(', '))
    accepted = RedactedAPI.formats_accepted.values.map(&:values)

    accepted.reject { |f| present.include? f }
  end

  def self.formats_accepted
    {
      'FLAC' => { format: 'FLAC', encoding: 'Lossless' },
      '320' => { format: 'MP3', encoding: '320' },
      'V0' => { format: 'MP3', encoding: 'V0 (VBR)' }
      # 'V2' => { format: 'MP3', encoding: 'V2 (VBR)' }
    }
  end

  def self.torrents_in_same_group?(t1, t2)
    t1['media'] == t2['media'] &&
      t1['remasterYear'] == t2['remasterYear'] &&
      t1['remasterTitle'] == t2['remasterTitle'] &&
      t1['remasterRecordLabel'] == t2['remasterRecordLabel'] &&
      t1['remasterCatalogueNumber'] == t2['remasterCatalogueNumber']
  end

  def deep_unescape_html(data)
    case data
    when Hash
      data.map { |k, v| [k, deep_unescape_html(v)] }.to_h
    when Array
      data.map { |e| deep_unescape_html(e) }
    when String
      HTMLEntities.new.decode(data)
    else
      data
    end
  end
end
