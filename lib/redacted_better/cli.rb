require "slop"

module RedactedBetter
  class Cli
    def initialize
      @opts = slop_parse

      if @opts[:help]
        puts @opts
        exit
      end

      # $quiet = @opts[:quiet]
      # $cache = SnatchCache.new(@opts[:cache_path], @opts[:delete_cache])
      # $account = Account.new(@opts[:username], @opts[:password])
      # $api = RedactedAPI.new(user_id: $account.user_id, cookie: $account.cookie)

      @config = Config.new(@opts[:config])
      @api = RedactedApi.new(@config.fetch(:api_key))
      @snatch_cache = SnatchCache.new(
        @config.fetch(:cache_path),
        @config.fetch(:delete_cache),
      )

      @download_directory = @config.fetch(:directories, :download)
      @output_directory = @config.fetch(:directories, :output)
      @torrents_directory = @config.fetch(:directories, :torrents)

      @user = confirm_api_connection
    end

    # @return [void]
    def start
      if @opts[:torrent]
        handle_single
      else
        handle_all_snatched
      end
    end

    private

    def handle_single
      url_data = parse_torrent_url(@opts[:torrent])
      torrent = @api.torrent(url_data[:torrent_id], @download_directory)
      torrent_group = @api.torrent_group(url_data[:group_id], @download_directory)

      @snatch_cache.add(torrent)

      success = handle_found_release(torrent_group, torrent)

      @snatch_cache.remove(torrent) unless success
    end

    def handle_all_snatched
      seeding = @api.user_torrents(@user["id"], type: :seeding)

      spinner = TTY::Spinner.new("[:spinner] Processing seeding list: :current")
      spinner.auto_spin
      seeding.each do |seeded|
        spinner.update(current: seeded[:torrent_group_name])

        next if @snatch_cache.contains?(seeded[:torrent_id])

        torrent = @api.torrent(seeded[:torrent_id], @download_directory)
        @snatch_cache.add(torrent)

        torrent_group = @api.torrent_group(seeded[:torrent_group_id], @download_directory)

        success = handle_found_release(torrent_group, torrent)

        @snatch_cache.remove(torrent) unless success
      end
    end

    # @param group [Group]
    # @param torrent [Torrent]
    #
    # @return [void]
    def handle_snatch(group, torrent)
      return if @cache.contains?(snatch[:torrent_id])

      if torrent
        handle_found_release(group, torrent)
      else
        Log.warning("Unable to find torrent #{snatch[:torrent_id]} in group #{snatch[:group_id]}.")
      end
      Log.info("")
    end

    # @param group [Group]
    # @param torrent [Torrent]
    #
    # @return [Boolean] successful?
    def handle_found_release(group, torrent)
      Log.info("")
      Log.info("Release found: #{torrent}")
      Log.info("  #{torrent.url}")

      formats_missing = group.formats_missing(torrent)

      if (files_missing = torrent.files_missing).any?
        Log.warning("  Missing #{files_missing.count} file(s):")
        files_missing.each { |f| Log.warning("  - #{f}") }

        return false
      end

      if (multichannel_files = torrent.multichannel_files).any?
        Log.warning("  Torrent is multichannel, skipping.")
        multichannel_files.each { |f| Log.warning("  - #{f}") }

        return false
      end

      if torrent.mislabeled_24bit?
        Log.error "Determined that the torrent is mislabeled 24-bit, not implemented."

        return false
        # fixed = handle_mislableled_torrent(torrent)
        # formats_missing << ["FLAC", "Lossless"] if fixed
      end

      unless formats_missing.any?
        @snatch_cache.add(torrent)

        return true
      end

      if (invalid_tagged_files = torrent.flac_files_with_invalid_tags).any?
        Log.warning("  One or more files has invalid tags, skipping.")
        invalid_tagged_files.each { |f| Log.warning("  - #{f}") }

        return false
      end

      torrent_files = []
      spinners = TTY::Spinner::Multi.new("[:spinner] Processing missing formats:")

      formats_missing.each do |format, encoding|
        spinners.register("[:spinner] #{format} #{encoding}:text") do |sp|
          if (torrent_file = perform_transcode(torrent, format, encoding, sp))
            torrent_files << { file: torrent_file, format: format, encoding: encoding }
          end
        end
      end

      spinners.auto_spin

      return false if torrent_files.none?

      spinners = TTY::Spinner::Multi.new("[:spinner] Uploading torrents:")

      torrent_files.each do |torrent_file|
        spinners.register("[:spinner] #{torrent_file[:format]} #{torrent_file[:encoding]}:text") do |sp|
          sp.update(text: " - Uploading...")

          if @api.upload_transcode(torrent, torrent_file[:format], torrent_file[:encoding], torrent_file[:file])
            sp.success("successfully uploaded!")
          else
            sp.error("failed.")
          end
        end
      end

      spinners.auto_spin

      true
    end

    # def handle_mislableled_torrent(torrent)
    #   if !$config.fetch(:fix_mislabeled_24bit)
    #     Log.warning("  Skipping fix of mislabeled 24-bit torrent.")
    #     false
    #   else
    #     $api.mark_torrent_24bit(torrent.id)
    #   end
    # end

    # Transcode a torrent to a target format.
    #
    # @param torrent [Torrent] the torrent to transcode
    # @param format [String]
    # @param encoding [String]
    #
    # @return [String, nil] the path to the created torrent file, otherwise nil
    #   if a problem occurred
    def perform_transcode(torrent, format, encoding, spinner = nil)
      if (result = Transcode.transcode(torrent, format, encoding, @output_directory, spinner))
        spinner&.update(text: " - Creating .torrent file...")

        torrent_file = torrent.make_torrent(
          result,
          @torrents_directory,
          format,
          encoding,
          @user["passkey"],
        )

        if torrent_file
          spinner.update(text: "")
          spinner.success(Pastel.new.green("Completed successfully."))

          return torrent_file
        end
      end

      spinner.error(Pastel.new.red("failed."))

      nil
    end

    # Takes a URL, meant to be provided on as a command-line parameter, and
    # extracts the group and torrent ids from it. The URL format is:
    # https://redacted.ch/torrents.php?id=1073646&torrentid=2311120
    #
    # @param url [String]
    #
    # @return [Hash{Symbol=>Integer}]
    def parse_torrent_url(url)
      match = url.match(/torrents\.php\?id=(\d+)&torrentid=(\d+)/)

      if !match || !match[1] || !match[2]
        Log.error("Unable to parse provided torrent URL.")
        exit
      end

      { group_id: match[1].to_i, torrent_id: match[2].to_i }
    end

    # @return [Hash] authenticated user data
    def confirm_api_connection
      spinner = TTY::Spinner.new("[:spinner] Authenticating...")
      spinner.auto_spin

      response = @api.get(action: "index")

      if response.success?
        spinner.success("successfully authenticated user: #{response.data["username"]}")

        response.data
      else
        spinner.error("failed to authenticate, check your API key.")
        exit 1
      end
    end

    # @return [Slop::Result]
    def slop_parse
      Slop.parse do |o|
        o.string "-c", "--config", "path to an alternate config file"
        o.bool "-q", "--quiet", "only print to STDOUT when errors occur"
        o.string "-k", "--api-key", "your redacted API key"
        o.string "--cache-path", "path to an alternate cache file"
        o.bool "--delete-cache", "invalidate the current cache"
        o.string "-t", "--torrent", "run for a single torrent, given a URL"
        o.bool "-h", "--help", "print help"
        o.on "-v", "--version", "print the version" do
          puts RedactedBetter::VERSION
          exit
        end
      end
    end
  end
end
