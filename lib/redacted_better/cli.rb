require "slop"

module RedactedBetter
  class Cli
    # @return [RedactedApi]
    attr_reader :api

    # @return [Config]
    attr_reader :config

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
      @api = RedactedApi.new(config.fetch(:api_key))
      @snatch_cache = SnatchCache.new(
        config.fetch(:cache_path),
        config.fetch(:delete_cache),
      )
    end

    # @return [void]
    def start
      user = confirm_api_connection(api)

      # @api.all_snatches()

      # if @opts[:torrent]
      #   handle_snatch(parse_torrent_url(@opts[:torrent]))
      # else
      #   snatches = $api.all_snatches
      #   Log.info("")
      #   snatches.each { |s| handle_snatch(s) }
      # end
    end

    private

    # @return [Hash] authenticated user data
    def confirm_api_connection(api)
      spinner = TTY::Spinner.new("[:spinner] Authenticating...")
      spinner.auto_spin

      response = api.get(action: "index")

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

    def handle_help_opt
    end
  end
end
