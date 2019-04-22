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

    spinner = TTY::Spinner.new("[:spinner] Loading snatches...", format: :dots_4)
    spinner.auto_spin

    until finished
      page = 1
      url = "torrents.php?type=snatched&userid=#{@user_id}&format=FLAC&page=#{page}"

      Request.wait_for_request

      response = Faraday.new(url: "https://redacted.ch/").get do |request|
        request.url url
        request.headers = Request.headers("cookie" => @cookie)
      end

      Request.notify_request_sent

      response.body.scan(parse_regex) do |group_id, torrent_id|
        next if @skip_ids.include? torrent_id.to_i

        result << { group_id: group_id.to_i, torrent_id: torrent_id.to_i }
      end

      finished = !response.body.include?("Next &gt;")
      page += 1
    end

    spinner.success(Pastel.new.green("done!"))

    result
  end

  def mark_torrent_24bit(torrent_id)
    spinner = TTY::Spinner.new("  [:spinner] Fixing mislabeled 24-bit torrent...", format: :dots_4)
    spinner.auto_spin

    agent = Mechanize.new
    page = agent.get("https://redacted.ch/torrents.php?action=edit&id=#{torrent_id}", [], nil, "Cookie" => @cookie)
    form = page.form("torrent")
    form.field_with(name: "bitrate").option_with(value: "24bit Lossless").click
    page = agent.submit(form, form.button_with(value: "Edit torrent"), "Cookie" => @cookie)

    if page.code.to_i == 200
      spinner.stop(Pastel.new.green("done!"))
      true
    else
      spinner.stop(Pastel.new.red("failed."))
      false
    end
  end

  def group_info(group_id)
    response = Request.send_request(
      action: "torrentgroup",
      cookie: @cookie,
      params: { id: group_id },
    )

    if response[:status] == "success"
      Utils.deep_unescape_html(response[:response])
    else
      Log.error("Failed to get info for torrent group #{group_id}.")
      false
    end
  end
end
