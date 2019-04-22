require "pry-byebug"

require "find"
require "json"

require "flacinfo"
require "htmlentities"
require "mechanize"

require "faraday"
require "pastel"
require "require_all"
require "slop"
require "tty-config"
require "tty-file"
require "tty-prompt"
require "tty-spinner"

require_rel "redacted_better"

class RedactedBetter
  def initialize
    $opts = Slop.parse do |o|
      o.string "-c", "--config", "path to an alternate config file"
      o.bool "-q", "--quiet", "only print to STDOUT when errors occur"
      o.string "-u", "--username", "your redacted username"
      o.string "-p", "--password", "your redacted password"
      o.bool "-h", "--help", "print help"
      o.on "-v", "--version", "print the version" do
        puts RedactedBetter::VERSION
        exit
      end
    end

    handle_help_opt
    $quiet = $opts[:quiet]

    $config = Config.load_config

    account = Account.new
    exit unless account.login

    $api = RedactedAPI.new(user_id: account.user_id, cookie: account.cookie)

    snatches = $api.all_snatches
    Log.info("")
    snatches.each do |snatch|
      next unless (info = $api.group_info(snatch[:group_id]))

      group = Group.new(info["group"])
      info["torrents"].each do |torrent_hash|
        group.torrents << Torrent.new(torrent_hash, group)
      end

      torrent = group.torrents.find { |t| t.id == snatch[:torrent_id] }

      if torrent
        handle_found_release(group, torrent)
      else
        Log.warning("Unable to find torrent #{snatch[:torrent_id]} in group #{snatch[:group_id]}.")
      end
      Log.info("")
    end
  end

  private

  def handle_found_release(group, torrent)
    Log.info("Release found: #{torrent}")
    Log.info("  #{torrent.url}")

    missing_files = torrent.missing_files

    if missing_files.any?
      Log.warning("  Missing #{missing_files.count} files(s):")
      missing_files.each { |f| Log.warning("    #{f}") }
      return
    end

    if torrent.any_multichannel?
      Log.warning("  Torrent is multichannel, skipping.")
      return
    end

    if torrent.mislabeled_24bit?
      if $config.fetch(:fix_mislabeled_24bit)
        Log.warning("  Skipping fix of mislabeled 24-bit torrent.")
      else
        $api.mark_torrent_24bit(torrent["id"])
      end
    end

    formats_missing = group.formats_missing(torrent)
    return unless formats_missing.any?

    tags_results = torrent.check_valid_tags
    unless tags_results[:valid]
      Log.error("  Found invalid tags:")
      tags_results[:errors].each do |file, message|
        Log.error("    #{file} - #{message}")
      end

      return
    end

    spinners = TTY::Spinner::Multi.new("[:spinner] Processing missing formats:")
    formats_missing.each do |f, e|
      spinners.register("[:spinner] #{f} #{e}:text") do |sp|
        Transcode.transcode(torrent, f, e, sp)
        sp.success(Pastel.new.green("done."))
      end
    end

    spinners.auto_spin
  end

  def handle_help_opt
    if $opts[:help]
      puts $opts
      exit
    end
  end
end
