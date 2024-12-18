require "marcel"
require "pathname"

module RedactedBetter
  class UploadWizard
    # @return [Pathname] the absolute path to either a single file (in the case
    #   of a single-file torrent) or the top-level torrent directory
    attr_reader :path

    # @return [Config]
    attr_reader :config

    # @return [Array<String>] a list of errors
    attr_reader :errors

    # @return [RedactedApi]
    attr_reader :red_api

    # @return [Ptpimg, nil]
    attr_reader :ptpimg

    # @return [Yadg, nil]
    attr_reader :yadg

    # @param path [String] the absolute path to either a single file (in the
    #   case of a single-file torrent) or the top-level torrent directory
    # @param config [Config]
    def initialize(path, config)
      @path = Pathname.new(path)
      @config = config

      @red_api = RedactedApi.new(config.fetch(:api_key))
      @yadg = Yadg.new(config.fetch(:yadg_api_key))
      @ptpimg = Ptpimg.new(config.fetch(:ptpimg_api_key))
      @user = @red_api.user

      @errors = []

      raise "Provided path does not exist." unless @path.exist?
    end

    # Get a list of absolute file paths for each file within the path directory
    # structure, regardless of file type.
    #
    # @return [Array<Pathname>]
    def absolute_file_paths
      @absolute_file_paths = if single_file?
          [path]
        else
          path.glob("**/*")
              .reject { |p| File.directory?(p) }
              .map { |ap| Pathname.new(ap) }
        end
    end

    # Get a list of file paths for each file within the path directory
    # structure, regardless of file type. Paths relative to (but still
    # including) the top-level torrent directory are provided.
    #
    # @return [Array<Pathname>]
    def relative_file_paths
      @relative_file_paths ||= absolute_file_paths.map { |p| p.sub("#{path.dirname}/", "") }
    end

    # Build a hash map between absolute paths (keys) and relative paths
    # (values).
    #
    # @return [Hash{Pathname=>Pathname}]
    def file_paths_map
      @file_paths_map ||= absolute_file_paths.zip(relative_file_paths).to_h
    end

    # Build a hash map between absolute paths (keys) and relative paths
    # (values), but with only non-audio files.
    #
    # @return [Hash{Pathname=>Pathname}]
    def non_audio_file_paths_map
      @non_audio_file_paths_map ||= absolute_non_audio_file_paths.zip(relative_non_audio_file_paths).to_h
    end

    # Get a list of absolute file paths for each file within the path directory
    # structure that is not an audio-file.
    #
    # @return [Array<Pathname>]
    def absolute_non_audio_file_paths
      @absolute_non_audio_file_paths ||= absolute_file_paths.reject { |p| audio_files.map(&:path).include?(p) }
    end

    # Get a list of file paths for each file within the path directory structure
    # that is not an audio-file. Paths relative to (but still including) the
    # top-level torrent directory are provided.
    #
    # @return [Array<Pathname>]
    def relative_non_audio_file_paths
      absolute_non_audio_file_paths.map { |p| p.sub("#{path.dirname}/", "") }
    end

    # @return [Array<AudioFile>]
    def audio_files
      @audio_files ||= absolute_file_paths.select { |p| AudioFile::ALLOWED_MIMETYPES.include? Marcel::MimeType.for(p) }
                                          .map { |p| AudioFile.new(p) }
    end

    # The path which contains the torrent directory (in the case of a multi-file
    # upload) or contains the single file (in the case of a single-file upload).
    #
    # @return [Pathname]
    def containing_directory
      path.dirname
    end

    # @return [Boolean]
    def single_file?
      path.file?
    end

    # @return [void]
    def start
      # Parse audio files to generate AudioFile list
      TTY::Spinner.new("[:spinner] Locating audio files...")
                  .tap do |spinner|
        spinner.auto_spin

        audio_files

        if audio_files.any?
          spinner.success(Pastel.new.green("done, found #{audio_files.count} audio files out of #{absolute_file_paths.count} total files"))
        else
          spinner.error(Pastel.new.yellow("unable to find any audio files"))
        end
      end

      unless check_all_files_for_errors
        Log.warning "Stopping because there was a problem with one or more files."
        exit 1
      end

      Log.info "\nEverything looks good, continuing with data collection.\n\n"

      wizard_prompt = WizardPrompt.new(self)
      wizard_prompt.collect_complete_data

      Log.info JSON.pretty_generate(wizard_prompt.data)

      return unless TTY::Prompt.new.yes?("OK to continue?")

      torrent_absolute_file_path = create_torrent_file(wizard_prompt)

      upload_torrent(torrent_absolute_file_path, wizard_prompt)
    end

    # @return [Boolean] true if no errors found, or if errors found do not
    #   warrant stopping the upload
    def check_all_files_for_errors
      all_files_ok = true
      absolute_audio_file_paths = audio_files.map(&:path)
      spinners = TTY::Spinner::Multi.new("[:spinner] Pre-processing files:")

      file_paths_map_without_root = file_paths_map.transform_values { |v| v.sub("#{path.basename}/", "") }
      longest_name_length = file_paths_map_without_root.values.map { |p| p.to_s.length }.max

      absolute_file_paths.each do |absolute_file_path|
        displayable_relative_path = file_paths_map_without_root[absolute_file_path].to_s.ljust(longest_name_length + 1)

        spinners.register("[:spinner] #{displayable_relative_path}:text") do |spinner|
          spinner.update(text: "Checking for problems...")

          if (path_length = absolute_file_path.to_s.length) > 180
            spinner.update(text: "")
            spinner.error(Pastel.new.red("is greater than 180 character path length limit (#{path_length})"))
            next
          end

          if absolute_audio_file_paths.include?(absolute_file_path)
            # @type [AudioFile]
            audio_file = audio_files.find { |af| af.path == absolute_file_path }
            raise "unable to find audio file: #{absolute_file_path}" unless audio_file

            audio_file.check_for_errors

            if audio_file.errors.any?
              all_files_ok = false
              spinner.update(text: "")
              spinner.error(Pastel.new.red(audio_file.errors.join(", ")))
              next
            end
          end

          spinner.update(text: "")
          spinner.success(Pastel.new.green("looks good"))
        end
      end

      spinners.auto_spin

      all_files_ok
    end

    # @param wizard_prompt [WizardPrompt]
    #
    # @return [Pathname] absolute path to the torrent file
    def create_torrent_file(wizard_prompt)
      metadata = wizard_prompt.data

      spinner = TTY::Spinner.new("[:spinner] Generating torrent file...")
      spinner.auto_spin

      torrent_file_name = Torrent.build_string(
        metadata.fetch(:artist),
        metadata.fetch(:release_name),
        metadata[:edition_year] || metadata.fetch(:initial_year),
        metadata.fetch(:media),
        Torrent.build_format(
          metadata.fetch(:format),
          metadata.fetch(:bitrate),
        ),
      )

      output_torrent_file_path = File.join(Dir.mktmpdir, "#{torrent_file_name}.torrent")
      tracker_url = "https://flacsfor.me/#{@user.fetch("passkey")}/announce"

      # Remove all .DS_Store files from the input path, recursively
      system("find \"#{path}\" -name \".DS_Store\" -delete")

      _stdout, stderr, status = Open3.capture3(
        "mktorrent -s RED -p -l 18 -a \"#{tracker_url}\" -o \"#{output_torrent_file_path}\" \"#{path}\"",
      )

      unless status.success?
        spinner.error(Pastel.new.red("Failed to create torrent file: Exit #{status.exitstatus}, #{stderr}"))
        exit 1
      end

      spinner.success(Pastel.new.green("done: #{torrent_file_name}.torrent"))

      Pathname.new output_torrent_file_path
    end

    # @param absolute_torrent_file_path [Pathname]
    # @param wizard_prompt [WizardPrompt]
    #
    # @return [void]
    def upload_torrent(absolute_torrent_file_path, wizard_prompt)
      spinner = TTY::Spinner.new("[:spinner] Uploading to RED...")
      spinner.auto_spin

      metadata = wizard_prompt.data

      post_body = {
        groupid: metadata[:group_id],
        file_input: Faraday::FilePart.new(File.open(absolute_torrent_file_path), "application/x-bittorrent"),
        type: 0, # music
        artists: [metadata.fetch(:artist)],
        importance: [1],
        title: metadata.fetch(:release_name),
        year: metadata.fetch(:initial_year),
        releasetype: metadata.fetch(:release_type),
        media: metadata.fetch(:media),
        remaster_year: metadata[:edition_year],
        remaster_title: metadata[:edition_title],
        remaster_record_label: metadata[:record_label],
        remaster_catalogue_number: metadata[:catalogue_number],
        format: metadata.fetch(:format),
        bitrate: metadata.fetch(:bitrate),
        vbr: metadata.fetch(:bitrate).downcase.include?("vbr"),
        logfiles: metadata.fetch(:log_files, [])
                          .map { |lf| Faraday::FilePart.new(File.open(lf), "text/plain") },
        vanity_house: metadata.fetch(:vanity_house),
        album_desc: metadata[:album_description],
        tags: metadata[:tags],
        release_desc: metadata.fetch(:release_description),
        image: metadata[:image_url_or_path],
      }.compact

      response = red_api.post(action: "upload", body: post_body)

      if response.success?
        FileUtils.cp(absolute_torrent_file_path, config.fetch(:directories, :torrents))
        new_url = "https://redacted.sh/torrents.php?id=#{response.data["groupid"]}&torrentid=#{response.data["torrentid"]}"
        spinner.success(Pastel.new.green("done: #{new_url}"))

        # if metadata[:format] == "FLAC" && prompt.yes?("Upload transcodes as well?")
        #   url_data = parse_torrent_url(new_url)
        #   torrent = @api.torrent(url_data[:torrent_id], @download_directory)
        #   torrent_group = @api.torrent_group(url_data[:group_id], @download_directory)

        #   handle_found_release(torrent_group, torrent)
        # end
      else
        message = "Failed to upload, response code: #{response.code}"
        spinner.error(Pastel.new.red(message))
        warn Pastel.new.red(response.data)
        exit 1
      end
    end
  end
end
