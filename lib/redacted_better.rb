require 'pry-byebug'

require 'faraday'
require 'pastel'
require 'require_all'
require 'slop'
require 'tty-config'
require 'tty-file'
require 'tty-prompt'
require 'tty-spinner'

require_rel 'redacted_better'

class RedactedBetter
  def initialize
    $opts = Slop.parse do |o|
      o.string '-c', '--config',   'path to an alternate config file'
      o.bool   '-q', '--quiet',    'only print to STDOUT when errors occur'
      o.string '-u', '--username', 'your redacted username'
      o.string '-p', '--password', 'your redacted password'
      o.bool   '-h', '--help',     'print help'
      o.on     '-v', '--version',  'print the version' do
        puts RedactedBetter::VERSION
        exit
      end
    end

    handle_help_opt
    $quiet = $opts[:quiet]

    $config = load_config

    account = Account.new
    exit unless account.login

    sp = SnatchParser.new(user_id: account.user_id, cookie: account.cookie)
    snatches = sp.all

    snatches.each do |snatch|
      next unless (info = sp.info_by_group_id(snatch[:group_id]))

      torrent = info['torrents'].find { |t| t['id'].to_i == snatch[:torrent_id] }
      if torrent
        artist_name = if info['group']['musicInfo']['artists'].count > 1
                        'Various Artists'
                      else
                        info['group']['musicInfo']['artists'].first['name']
                      end
        release_name = info['group']['name']
        release_year = torrent['remastered'] ? torrent['remasterYear'] : info['group']['year']
        format = torrent['format']

        info_str = "#{artist_name} - #{release_name} (#{release_year}) [#{format}]"
        Log.info("Release found: #{info_str}")
      else
        Log.warning("Unable to find torrent #{snatch[:torrent_id]} in group #{snatch[:group_id]}.")
      end
    end
  end

  def self.root
    File.expand_path('..', __dir__)
  end

  private

  def handle_help_opt
    if $opts[:help]
      puts $opts
      exit
    end
  end

  def load_config
    config = TTY::Config.new

    if $opts[:config]
      # User has supplied an alternate config file path
      if File.exist? $opts[:config]
        config.prepend_path File.dirname($opts[:config])
        config.filename = File.basename($opts[:config], '.*')
      else
        Log.error('No configuration file at provided path.')
        exit
      end
    else
      # User wants to use the built in config file path
      default_path = File.join(Dir.home, '.config', 'redacted_better')
      config.prepend_path default_path
      TTY::File.create_dir(default_path)
      config.filename = 'redacted_better'
      config.extname = '.yaml'

      full_path = File.join(default_path, config.filename + config.extname)
      unless File.exist? full_path
        # Copy default config file into place
        TTY::File.copy_file('default_config.yaml', full_path) do |f|
          "# Default config file, created at #{Time.now}\n\n" + f
        end
      end
    end

    config.read
    config
  end
end
