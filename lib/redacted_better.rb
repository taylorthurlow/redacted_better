# require 'pry-byebug'

require 'find'
require 'json'

require 'flacinfo'
require 'htmlentities'
require 'mechanize'

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

    api = RedactedAPI.new(user_id: account.user_id, cookie: account.cookie)

    api.all_snatches.each do |snatch|
      next unless (info = api.info_by_group_id(snatch[:group_id]))

      torrent = info['torrents'].find { |t| t['id'] == snatch[:torrent_id] }
      if torrent
        handle_found_release(api, info['group'], torrent, info['torrents'])
      else
        Log.warning("Unable to find torrent #{snatch[:torrent_id]} in group #{snatch[:group_id]}.")
      end
      Log.info('')
    end
  end

  def self.root
    File.expand_path('..', __dir__)
  end

  private

  def handle_found_release(api, group, torrent, all_torrents)
    Log.info("Release found: #{release_info_string(group, torrent)}")
    Log.info("  https://redacted.ch/torrents.php?id=#{group['id']}&torrentid=#{torrent['id']}")
    file_list = torrent['fileList'].gsub(/\|\|\|/, '').split(/\{\{\{\d+\}\}\}/)
    dl_dir = $config.fetch(:directories, :download)

    if torrent['filePath'] # is the torrent stored in a single directory?
      flac_path = File.join(dl_dir, torrent['filePath'])

      unless Dir.exist?(flac_path)
        Log.warning('  Torrent is snatched but missing from download directory.')
        return
      end

      missing_files = file_list.count { |f| !File.exist? File.join(flac_path, f) }
    else
      missing_files = file_list.count { |f| !File.exist? File.join(dl_dir, f) }
    end

    if missing_files.positive?
      Log.warning("  Missing #{missing_files} files(s), skipping.")
      return
    end

    if Transcode.directory_any_multichannel?(flac_path)
      Log.warning('  Release is multichannel, skipping torrent.')
      return
    end

    if Transcode.directory_is_24bit?(flac_path) && torrent['encoding'] != '24bit Lossless'
      if $config.fetch(:fix_mislabeled_24bit)
        Log.warning('  Skipping fix of mislabeled 24-bit torrent.')
      else
        api.set_torrent_24bit(torrent['id'])
      end
    end

    formats_missing = api.formats_missing(group, torrent, all_torrents)
    if formats_missing.any?
      missing_string = formats_missing.map { |f| f.join(' ') }.join(', ')
      Log.success("  Missing formats: #{missing_string}")
    else
      Log.info("  No formats missing.")
    end

#     spinners = TTY::Spinner::Multi.new('[:spinner] top')

#     sp1 = spinners.register '[:spinner] one'
#     sp2 = spinners.register '[:spinner] two'

#     sp1.auto_spin
#     sp2.auto_spin

#     sleep(5) # Perform work

#     sp1.success
#     sp2.success
  end

  def release_info_string(group, torrent)
    artist_name = if group['musicInfo']['artists'].count > 1
                    'Various Artists'
                  else
                    group['musicInfo']['artists'].first['name']
                  end
    release_name = group['name']
    release_year = torrent['remastered'] ? torrent['remasterYear'] : group['year']
    format = torrent['format']

    "#{artist_name} - #{release_name} (#{release_year}) [#{format}]"
  end

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
