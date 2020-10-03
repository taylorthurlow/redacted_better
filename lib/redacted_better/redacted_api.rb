module RedactedBetter
  class RedactedApi
    # @return [String]
    attr_reader :api_key

    # @return [Array<Time>]
    attr_accessor :request_log

    # @return [String]
    attr_reader :base_url

    # @param api_key [String]
    def initialize(api_key)
      @api_key = api_key
      @request_log = []
      @base_url = "https://redacted.ch/"
    end

    # @param action [String] the API action name
    # @param params [Hash] additional URL parameters
    #
    # @return [Response]
    def get(action:, params: {})
      wait_for_rate_limit do
        response = Faraday.new(url: base_url).get do |request|
          url = "ajax.php?action=#{action}"
          params.each { |p, v| url += "&#{p}=#{v}" }
          request.url url
          request.headers.merge!(build_headers)
        end

        Response.new(
          code: response.status,
          body: response.body,
        )
      end
    end

    # @param user_id [Integer] ID number of the user
    #
    # @return [Array<Hash>]
    def all_snatches(user_id)
      finished = false
      result = []

      spinner = TTY::Spinner.new("[:spinner] Fetching snatches page :page_number...")
      spinner.update(page_number: 1)
      spinner.auto_spin

      page = 1
      per_page = 500

      until finished
        spinner.update(page_number: page)

        response = get(
          action: "user_torrents",
          params: {
            id: user_id,
            type: "snatched",
            limit: per_page,
            offset: (page * per_page) - 500,
          },
        )

        if response.data["snatched"].any?
          result += response.data["snatched"]
                            .map do |snatched|
            {
              torrent_group_id: snatched["groupId"],
              torrent_group_name: snatched["name"],
              torrent_id: snatched["torrentId"],
            }
          end

          page += 1
        else
          finished = true
          spinner.success(Pastel.new.green("done."))
        end
      end

      result
    end

    # Fetch a torrent from the API.
    #
    # @param id [Integer]
    # @param download_directory [String]
    #
    # @return [Torrent]
    def torrent(id, download_directory)
      response = get(
        action: "torrent",
        params: { id: id },
      )

      group = Group.new(response.data["group"])

      Torrent.new(response.data["torrent"], group, download_directory)
    end

    # Fetch a torrent group from the API, including child torrents.
    #
    # @param id [Integer]
    # @param download_directory [String]
    #
    # @return [Group]
    def torrent_group(id, download_directory)
      response = get(
        action: "torrentgroup",
        params: { id: id },
      )

      group = Group.new(response.data["group"])
      group.torrents += response.data["torrents"].map do |t|
        Torrent.new(t, group, download_directory)
      end

      group
    end

    private

    # @param additional_headers [Hash{String=>String}]
    #
    # @return [Hash{String => String}]
    def build_headers(additional_headers = {})
      {
        "User-Agent" => RedactedBetter.user_agent,
        "Authorization" => api_key,
      }.merge!(additional_headers)
    end

    # Run some code, ensuring that we don't make more than 5 requests in a
    # 10-second rolling window.
    #
    # @return [void]
    def wait_for_rate_limit
      while requests_in_last_ten_seconds >= 5
        sleep(0.1)
      end

      log_request(Time.now)

      yield
    end

    # @param time [Time]
    def log_request(time)
      request_log << time
    end

    # @return [Integer]
    def requests_in_last_ten_seconds
      start_window = Time.now - 10

      request_log.count { |req_time| req_time >= start_window }
    end

    # def mark_torrent_24bit(torrent_id)
    #   unless $quiet
    #     spinner = TTY::Spinner.new("  [:spinner] Fixing mislabeled 24-bit torrent...", format: :dots_4)
    #     spinner.auto_spin
    #   end

    #   agent = Mechanize.new
    #   agent.user_agent = RedactedBetter.user_agent
    #   url = "https://redacted.ch/torrents.php?action=edit&id=#{torrent_id}"
    #   page = agent.get(url, [], nil, "Cookie" => @cookie)

    #   page_text = page.search("#content").text.gsub(/\s+/, " ")
    #   if page_text.include? "Error 403"
    #     spinner&.stop(Pastel.new.red("unable to fix, not allowed to edit this torrent"))
    #     return false
    #   end

    #   form = page.form("torrent")
    #   form.field_with(name: "bitrate").option_with(value: "24bit Lossless").click
    #   page = agent.submit(form, form.button_with(value: "Edit torrent"), "Cookie" => @cookie)

    #   if page.code.to_i == 200
    #     spinner&.stop(Pastel.new.green("done!"))
    #     true
    #   else
    #     spinner&.stop(Pastel.new.red("failed."))
    #     false
    #   end
    # end

    # def group_info(group_id)
    #   response = Request.send_request_action(
    #     action: "torrentgroup",
    #     cookie: @cookie,
    #     params: { id: group_id },
    #   )

    #   if response[:status] == "success"
    #     Utils.deep_unescape_html(response[:response])
    #   else
    #     Log.error("Failed to get info for torrent group #{group_id}.")
    #     false
    #   end
    # end
  end
end
