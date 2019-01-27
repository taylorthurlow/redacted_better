require 'pry-byebug'

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
    Log.info("Release found: #{Utils.release_info_string(group, torrent)}")
    Log.info('  https://redacted.ch/torrents.php' \
                                   "?id=#{group['id']}" \
                                   "&torrentid=#{torrent['id']}")

    dl_dir = $config.fetch(:directories, :download)
    # torrent['filePath'] might not be set but will not be included in the path
    # if it is blank
    torrent_path = File.join(dl_dir, torrent['filePath'])
    file_list = torrent['fileList'].gsub(/\|\|\|/, '')
                                   .split(/\{\{\{\d+\}\}\}/)
                                   .map { |p| File.join(torrent_path, p) }

    # is the torrent stored in a directory as required?
    properly_contained = !torrent['filePath'].empty?

    missing_files = file_list.reject { |f| File.exist?(f) }
                             .map { |f| File.basename(f) }

    if missing_files.any?
      Log.warning("  Missing #{missing_files.count} files(s):")
      missing_files.each { |f| Log.warning("    #{f}") }
      return
    end

    if Transcode.any_multichannel?(file_list)
      Log.warning('  Release is multichannel, skipping torrent.')
      return
    end

    fixed_24bit = false
    if Transcode.mislabeled_24bit?(file_list, torrent['encoding'])
      if $config.fetch(:fix_mislabeled_24bit)
        Log.warning('  Skipping fix of mislabeled 24-bit torrent.')
      else
        fixed_24bit = api.set_torrent_24bit(torrent['id'])
      end
    end

    formats_missing = api.formats_missing(group, torrent, all_torrents)

    unless formats_missing.any?
      Log.info('  No formats missing.')
      return
    end

    missing_string = formats_missing.map { |f| f.join(' ') }.join(', ')
    Log.success("  Missing formats: #{missing_string}")

    tags_results = Tags.all_valid_tags?(file_list)

    unless tags_results[:valid]
      Log.error('  Found invalid tags:')
      tags_results[:errors].each do |file, message|
        Log.error("    #{file} - #{message}")
      end

      return
    end

    formats_missing.each { |f, e| handle_missing_format(f, e, api, fixed_24bit) }
  end

  def handle_missing_format(format, encoding, _api, fixed_24bit)
    Log.debug("Handle missing format #{format} #{encoding}.")
    #     spinners = TTY::Spinner::Multi.new('[:spinner] top')

    #     sp1 = spinners.register '[:spinner] one'
    #     sp2 = spinners.register '[:spinner] two'

    #     sp1.auto_spin
    #     sp2.auto_spin

    #     sleep(5) # Perform work

    #     sp1.success
    #     sp2.success
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
