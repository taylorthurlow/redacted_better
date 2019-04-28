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

    unless $quiet
      spinner = TTY::Spinner.new("[:spinner] Loading snatches...", format: :dots_4)
      spinner.auto_spin
    end

    until finished
      page = 1
      url = "torrents.php?type=snatched&userid=#{@user_id}&format=FLAC&page=#{page}"

      response = Request.send_request(url, @cookie)

      response.body.scan(parse_regex) do |group_id, torrent_id|
        next if @skip_ids.include? torrent_id.to_i

        result << { group_id: group_id.to_i, torrent_id: torrent_id.to_i }
      end

      finished = !response.body.include?("Next &gt;")
      page += 1
    end

    spinner&.success(Pastel.new.green("done!"))

    result
  end

  def mark_torrent_24bit(torrent_id)
    unless $quiet
      spinner = TTY::Spinner.new("  [:spinner] Fixing mislabeled 24-bit torrent...", format: :dots_4)
      spinner.auto_spin
    end

    agent = Mechanize.new
    agent.user_agent = RedactedBetter.user_agent
    url = "https://redacted.ch/torrents.php?action=edit&id=#{torrent_id}"
    page = agent.get(url, [], nil, "Cookie" => @cookie)

    page_text = page.search("#content").text.gsub(/\s+/, " ")
    if page_text.include? "Error 403"
      spinner&.stop(Pastel.new.red("unable to fix, not allowed to edit this torrent"))
      return false
    end

    form = page.form("torrent")
    form.field_with(name: "bitrate").option_with(value: "24bit Lossless").click
    page = agent.submit(form, form.button_with(value: "Edit torrent"), "Cookie" => @cookie)

    if page.code.to_i == 200
      spinner&.stop(Pastel.new.green("done!"))
      true
    else
      spinner&.stop(Pastel.new.red("failed."))
      false
    end
  end

  def group_info(group_id)
    response = Request.send_request_action(
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
