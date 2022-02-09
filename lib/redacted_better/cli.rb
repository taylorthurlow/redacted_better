require "digest"
require "slop"

module RedactedBetter
  class Cli
    def initialize
      @opts = slop_parse

      if @opts[:help]
        puts @opts
        exit
      end

      @config = Config.new(@opts[:config])
      @api = RedactedApi.new(@config.fetch(:api_key))

      @download_directory = @config.fetch(:directories, :download)
      @output_directory = @config.fetch(:directories, :output)
      @torrents_directory = @config.fetch(:directories, :torrents)

      @user = confirm_api_connection
    end

    # @return [void]
    def start
      @opts.args.each do |arg|
        url_data = parse_torrent_url(arg)
        torrent = @api.torrent(url_data[:torrent_id], @download_directory)
        torrent_group = @api.torrent_group(url_data[:group_id], @download_directory)

        handle_found_release(torrent_group, torrent)
      end
    end

    private

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
        Log.warning "The source torrent is labeled as 16-bit FLAC but it is actually 24-bit FLAC. This torrent should be reported and fixed."

        # return false
        # fixed = handle_mislableled_torrent(torrent)
        # formats_missing << ["FLAC", "Lossless"] if fixed
      end

      return true if formats_missing.none?

      if (invalid_tagged_files = torrent.flac_files_with_invalid_tags).any?
        Log.warning("  One or more files has invalid tags, skipping.")
        invalid_tagged_files.each { |f| Log.warning("  - #{f}") }

        return false
      end

      ready_uploads = []
      spinners = TTY::Spinner::Multi.new("[:spinner] Processing missing formats:")

      formats_missing.each do |format, encoding|
        # Temporary container to store data for this pass
        ready_upload = { transcodes: [] }

        spinners.register("[:spinner] #{format} #{encoding}:text") do |spinner|
          # Determine the new torrent directory name
          torrent_name = Torrent.build_string(
            torrent.group.artist,
            torrent.group.name,
            torrent.year,
            torrent.media,
            Torrent.build_format(format, encoding),
          )

          ready_upload[:name] = torrent_name

          # Get final output dir and make sure it doesn't already exist
          torrent_dir = File.join(@output_directory, torrent_name)

          if Dir.exist?(torrent_dir)
            spinner&.update(text: " - Failed")
            spinner&.error(Pastel.new.red("(output directory exists)"))

            next
          end

          temp_torrent_dir = File.join(Dir.mktmpdir, torrent_name)
          ready_upload[:temp_dir] = temp_torrent_dir
          FileUtils.mkdir_p(temp_torrent_dir)

          torrent.flac_files.each do |file_path|
            spinner&.update(text: " - #{File.basename(file_path)}")
            new_file_name = "#{File.basename(file_path, ".*")}.#{format.downcase}"
            destination_file = File.join(temp_torrent_dir, new_file_name)

            transcode = Transcode.new(format, encoding, file_path, destination_file)

            if transcode.errors.any?
              spinner&.error(Pastel.new.red("Transcode failed: #{transcode.errors.join(", ")}"))

              return false
            end

            if transcode.process
              ready_upload[:transcodes] << transcode
            else
              spinner&.error(Pastel.new.red("Transcode failed: #{transcode.errors.join(", ")}"))

              return false
            end
          end

          # Create final output directory and copy the finished transcode from
          # the temp directory into it
          FileUtils.mv(temp_torrent_dir, @output_directory)

          spinner&.update(text: " - Creating .torrent file...")

          torrent_file = torrent.make_torrent(
            torrent_dir,
            format,
            encoding,
            @user["passkey"],
          )

          FileUtils.cp(torrent_file, @torrents_directory)

          spinner.update(text: "")
          spinner.success(Pastel.new.green("Completed successfully."))

          ready_uploads << ready_upload.merge(
            file: torrent_file,
            format: format,
            encoding: encoding,
          )
        ensure
          FileUtils.remove_dir(temp_torrent_dir, true) if temp_torrent_dir
        end
      end

      spinners.auto_spin

      return false if ready_uploads.none?

      return true if @opts[:skip_upload]

      spinners = TTY::Spinner::Multi.new("[:spinner] Uploading torrents:")

      ready_uploads.each do |upload|
        spinners.register("[:spinner] #{upload.fetch(:format)} #{upload.fetch(:encoding)}:text") do |sp|
          sp.update(text: " - Generating descriptions...")

          release_description = <<~DESCRIPTION
            This torrent was transcoded/compiled by redacted_better v#{RedactedBetter::VERSION}, an automated script.

            Transcoded from: #{torrent.url}

            [quote][pre]#{libraries_breakdown.to_yaml.split("\n")[1..].join("\n")}[/pre][/quote]

          DESCRIPTION

          spectrals = []
          if @config.fetch(:ptpimg_api_key, default: nil) && upload.fetch(:format) == "FLAC"
            ptpimg_client = Ptpimg.new(@config.fetch(:ptpimg_api_key))
          end

          upload.fetch(:transcodes).each.with_index do |transcode, i|
            commands = transcode.command_list
                                .join("\n")
                                .gsub(upload.fetch(:temp_dir), "/anon_temp_dir")

            final_file = File.join(@output_directory, upload.fetch(:name), File.basename(transcode.destination))

            if ptpimg_client
              sp.update(text: " - Generating spectrogram #{i + 1}...")
              spectrals << generate_spectrogram(final_file)
            end

            release_description << <<~DESCRIPTION
              [hide="#{File.basename(transcode.destination)}"]
                [quote][pre]#{`mediainfo "#{final_file}"`.chomp}[/pre][/quote]

                [pre]#{commands}[/pre]

                #{"{{spectral-#{i + 1}}}" if ptpimg_client}
              [/hide]
            DESCRIPTION
          end

          # TODO: Skip spectrals if ptpimg api key not configured

          if ptpimg_client
            sp.update(text: " - Uploading spectrograms...")

            if (images = ptpimg_client.upload(spectrals))
              spectrals.each_with_index do |spectral_path, i|
                release_description.gsub!(
                  "{{spectral-#{i + 1}}}",
                  <<~REPLACE,
                  [img]#{images.fetch(spectral_path)}[/img]
                REPLACE
                )
              end
            else
              spectrals.each_with_index do |_, i|
                release_description.gsub!("{{spectral-#{i + 1}}}", "Failure to upload, sorry!")
              end
            end
          end

          release_description = sanitize_personal_paths(release_description).chomp

          sp.update(text: " - Uploading to RED...")
          if @api.upload_transcode(
            torrent,
            upload.fetch(:format),
            upload.fetch(:encoding),
            upload.fetch(:file),
            release_description,
          )
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

    # @return [Hash{String=>String}]
    def libraries_breakdown
      convmv = begin
          `convmv --help`.split("\n")
                         .find { |l| l.start_with?("convmv ") }
                         &.gsub(/ - .+$/, "")
        rescue Errno::ENOENT
          nil
        end

      {
        "flac" => `flac -v`.strip,
        "sox" => `sox --version`.strip.gsub(/^sox:\s+/, ""),
        "mktorrent" => `mktorrent -h`.split("\n").first.strip,
        "lame" => `lame --version`.split("\n").first,
        "mediainfo" => `mediainfo --version`.gsub("\n", " ").strip,
        "convmv" => convmv || "not installed",
      }
    end

    # @param string [String]
    #
    # @return [String]
    def sanitize_personal_paths(string)
      string.gsub(@torrents_directory, "/anon_torrents_dir")
            .gsub(@output_directory, "/anon_output_dir")
            .gsub(@download_directory, "/anon_download_dir")
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

    # @param file_path [String]
    #
    # @return [String, nil] the full image path, or nil if failed
    def generate_spectrogram(file_path)
      name = File.basename(file_path)

      # Memoize the generated file based on the MD5 of the input file - this way
      # we send the same image to ptpimg, which is smart enough to give us back
      # the same URL and not waste storage.
      file = File.open(file_path)
      md5 = Digest::MD5.file(file)
      out_path = File.join(Dir.tmpdir, "#{md5}-spectrogram.png")

      if File.exist?(out_path)
        out_path
      else
        `sox "#{file_path}" -n remix 1 spectrogram -x 1500 -y 500 -z 120 -w Kaiser -t "#{name}" -o "#{out_path}"`

        out_path if $?.success?
      end
    ensure
      file&.close
    end

    # @return [Slop::Result]
    def slop_parse
      Slop.parse do |o|
        o.string "-c", "--config", "path to an alternate config file"
        o.bool "-q", "--quiet", "only print to STDOUT when errors occur"
        o.string "-k", "--api-key", "your redacted API key"
        o.bool "--skip-upload", "skip uploading to RED"
        o.bool "-h", "--help", "print help"
        o.on "-v", "--version", "print the version" do
          puts RedactedBetter::VERSION
          exit
        end
      end
    end
  end
end
