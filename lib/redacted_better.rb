require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.push_dir(File.expand_path("../lib", __dir__))
loader.setup

require "pry-byebug"

require "find"
require "json"

require "flacinfo"
require "htmlentities"
require "mechanize"

require "faraday"
require "pastel"
require "tty-config"
require "tty-file"
require "tty-prompt"
require "tty-spinner"

module RedactedBetter
  # @return [String]
  def self.user_agent
    "redacted_better/#{VERSION} (taylorthurlow/redacted_better@github)"
  end

  private

  # # Takes a URL, meant to be provided on as a command-line parameter, and
  # # extracts the group and torrent ids from it. The URL format is:
  # # https://redacted.ch/torrents.php?id=1073646&torrentid=2311120
  # def parse_torrent_url(url)
  #   match = @opts[:torrent].match /torrents\.php\?id=(\d+)&torrentid=(\d+)/

  #   if !match || !match[1] || !match[2]
  #     Log.error("Unable to parse provided torrent URL.")
  #     exit
  #   end

  #   { group_id: match[1].to_i, torrent_id: match[2].to_i }
  # end

  # def handle_snatch(snatch)
  #   return if $cache.contains?(snatch[:torrent_id])
  #   return unless (info = $api.group_info(snatch[:group_id]))

  #   group = Group.new(info["group"])
  #   info["torrents"].each do |torrent_hash|
  #     group.torrents << Torrent.new(torrent_hash, group)
  #   end

  #   torrent = group.torrents.find { |t| t.id == snatch[:torrent_id] }

  #   if torrent
  #     handle_found_release(group, torrent)
  #   else
  #     Log.warning("Unable to find torrent #{snatch[:torrent_id]} in group #{snatch[:group_id]}.")
  #   end
  #   Log.info("")
  # end

  # def handle_found_release(group, torrent)
  #   Log.info("Release found: #{torrent}")
  #   Log.info("  #{torrent.url}")

  #   formats_missing = group.formats_missing(torrent)

  #   return false if torrent_missing_files?(torrent)
  #   return false if torrent_any_multichannel?(torrent)

  #   if torrent.mislabeled_24bit?
  #     fixed = handle_mislableled_torrent(torrent)
  #     formats_missing << ["FLAC", "Lossless"] if fixed
  #   end

  #   unless formats_missing.any?
  #     $cache.add(torrent)
  #     return true
  #   end

  #   return false unless torrent.valid_tags?

  #   start_transcodes(torrent, formats_missing)

  #   true
  # end

  # def torrent_any_multichannel?(torrent)
  #   if torrent.any_multichannel?
  #     Log.warning("  Torrent is multichannel, skipping.")
  #     return true
  #   end

  #   false
  # end

  # def handle_mislableled_torrent(torrent)
  #   if !$config.fetch(:fix_mislabeled_24bit)
  #     Log.warning("  Skipping fix of mislabeled 24-bit torrent.")
  #     false
  #   else
  #     $api.mark_torrent_24bit(torrent.id)
  #   end
  # end

  # def torrent_missing_files?(torrent)
  #   missing_files = torrent.missing_files

  #   if missing_files.any?
  #     Log.warning("  Missing #{missing_files.count} files(s):")
  #     missing_files.each { |f| Log.warning("    #{f}") }
  #     return true
  #   end

  #   false
  # end

  # def start_transcodes(torrent, formats_missing)
  #   if $quiet
  #     formats_missing.each { |f, e| Transcode.transcode(torrent, f, e) }
  #   else
  #     spinners = TTY::Spinner::Multi.new("[:spinner] Processing missing formats:")
  #     formats_missing.each do |f, e|
  #       spinners.register("[:spinner] #{f} #{e}:text") do |sp|
  #         result = Transcode.transcode(torrent, f, e, sp)

  #         if result
  #           sp&.update(text: " - Creating .torrent file.")
  #           if torrent.make_torrent(f, e, result)
  #             sp.error(Pastel.new.red("failed."))
  #           else
  #             sp.success(Pastel.new.green("done."))
  #           end
  #         else
  #           sp.error(Pastel.new.red("failed."))
  #         end
  #       end
  #     end

  #     spinners.auto_spin
  #   end
  # end
end
