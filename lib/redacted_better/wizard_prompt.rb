require "json"

module RedactedBetter
  class WizardPrompt
    # @return [UploadWizard]
    attr_reader :wizard

    # @return [Group, nil]
    attr_reader :group

    attr_reader :group_id
    attr_reader :artist
    attr_reader :release_name
    attr_reader :release_type
    attr_reader :initial_year
    attr_reader :edition_year
    attr_reader :edition_title
    attr_reader :record_label
    attr_reader :catalogue_number
    attr_reader :scene
    attr_reader :vanity_house
    attr_reader :format
    attr_reader :bitrate
    attr_reader :media
    attr_reader :log_files
    attr_reader :tags
    attr_reader :album_description
    attr_reader :image_url_or_path
    attr_reader :release_description

    PROMPTABLE_ATTRIBUTES = %i[
      group_id artist release_name release_type initial_year edition_year
      edition_title record_label catalogue_number scene vanity_house format
      bitrate media log_files tags album_description image_url_or_path
      release_description
    ].freeze

    # @param wizard [UploadWizard]
    def initialize(wizard)
      @wizard = wizard
      @group = nil
    end

    # Prompt for values for any "promptable" attribute that has a value of nil.
    # This will allow us to skip prompts entirely for attributes that have
    # already been set.
    def collect_complete_data
      PROMPTABLE_ATTRIBUTES.each do |promptable_attribute|
        next unless send(promptable_attribute).nil?

        new_value = send("prompt_#{promptable_attribute}".to_sym)
        instance_variable_set("@#{promptable_attribute}".to_sym, new_value)
      end
    end

    # @return [Hash{Symbol=>Object}]
    def data
      PROMPTABLE_ATTRIBUTES.to_h { |at| [at, send(at)] }
                           .compact
    end

    # @return [String]
    def inspect
      "WizardPrompt"
    end

    private

    # TODO: Determine which questions can be skipped when the group number is
    # provided

    def prompt
      @prompt ||= TTY::Prompt.new(interrupt: :exit)
    end

    # @return [Integer]
    def prompt_group_id
      group_id = prompt.ask("Group ID number, if it exists:") do |q|
        q.convert :integer
      end

      return unless group_id

      @group = group_from_group_id(group_id)

      prompt.say <<~SAY

                   Matched group ID #{group_id}:
                     #{@group.name} (#{group.year})
                     Artist(s): #{group.artists.map { |a| a["name"] }.join(", ")}

                     Label: #{group.record_label}
                     Release type: #{group.release_type}
                     Category ID: #{group.category_id}
                     Category name: #{group.category_name}
                     Vanity house: #{group.vanity_house}
                     Tags: #{group.tags}

                 SAY

      group_id
    end

    # @return [String]
    def prompt_artist
      return group.artists.first["name"] if group

      prompt.ask("Artist:") do |q|
        q.required true
        q.default wizard.audio_files.first.artist
      end
    end

    # @return [String]
    def prompt_release_name
      return group.name if group

      prompt.ask("Release name:") do |q|
        q.required true
        q.default wizard.audio_files.first.album
      end
    end

    # @return [Integer]
    def prompt_release_type
      return group.release_type if group

      prompt.select(
        "Release type:",
        [
          { name: "Album", value: 1 },
          { name: "EP", value: 5 },
          { name: "Single", value: 9 },
          { name: "Live album", value: 11 },
          { name: "Soundtrack", value: 3 },
          { name: "Remix", value: 13 },
          { name: "Bootleg", value: 14 },
          { name: "Mixtape", value: 16 },
          { name: "Demo", value: 17 },
          { name: "Interview", value: 15 },
          { name: "Concert recording", value: 18 },
          { name: "Anthology", value: 6 },
          { name: "Compilation", value: 7 },
          { name: "DJ mix", value: 19 },
          { name: "Unknown", value: 21 },
        ],
        filter: true,
      ) do |q|
        q.default wizard.audio_files.count == 1 ? "Single" : "Album"
      end
    end

    def prompt_initial_year
      return group.year if group

      prompt.ask("Initial year:") do |q|
        q.required true

        if (year_matches = wizard.audio_files.first.date.scan(/\d{4}/)).any?
          q.default year_matches.first
        end
      end
    end

    def prompt_edition_year
      prompt.ask("Edition year:") do |q|
        q.required true
        q.default initial_year
      end
    end

    def prompt_edition_title
      prompt.ask("Edition title:")
    end

    def prompt_record_label
      prompt.ask("Record label:") do |q|
        q.default wizard.audio_files.first.label || group&.record_label
      end
    end

    def prompt_catalogue_number
      prompt.ask("Catalogue number:") do |q|
        q.default group&.catalogue_number
      end
    end

    def prompt_scene
      answer = prompt.yes?("Scene release?") do |q|
        q.default false
      end

      prompt.warn("Be sure you understand the rules regarding uploading a Scene release!") if answer

      answer
    end

    def prompt_vanity_house
      return group.vanity_house if group

      prompt.yes?("Vanity house release?") do |q|
        q.default false
      end
    end

    def prompt_format
      prompt.select("Format:", %w[MP3 FLAC AAC AC3 DTS], filter: true) do |q|
        q.default wizard.audio_files.first.format
      end
    end

    def prompt_bitrate
      prompt.select(
        "Bitrate:",
        [
          "Lossless",
          "24bit Lossless",
          "320",
          "256",
          "192",
          "V0 (VBR)",
          "V1 (VBR)",
          "V2 (VBR)",
          "APS (VBR)",
          "APX (VBR)",
        ],
        filter: true,
      ) do |q|
        if wizard.audio_files.first.format == "FLAC"
          q.default wizard.audio_files.first.bit_depth == 24 ? "24bit Lossless" : "Lossless"
        end
      end
    end

    def prompt_media
      prompt.select(
        "Media:",
        [
          "CD",
          "WEB",
          "Vinyl",
          "Soundboard",
          "DVD",
          "Blu-Ray",
          "Cassette",
          "SACD",
          "DAT",
        ],
        filter: true,
      ) do |q|
        q.default wizard.relative_file_paths.any? { |p| p.extname.downcase == ".log" } ? "CD" : "WEB"
      end
    end

    def prompt_log_files
      return unless media == "CD"

      prompt.multi_select(
        "Select CD LOG files, if any:",
        wizard.non_audio_file_paths_map.map { |abs, rel| { name: rel.sub("#{wizard.path.basename}/", ""), value: abs } },
        filter: true,
      )
    end

    def prompt_tags
      return if group

      prompt.ask("Tags (comma-separated)") do |q|
        q.modify :down, :remove
        q.validate ->(input) { input.nil? || input.empty? || input =~ /\A[A-Za-z0-9.,]+\Z/ }
        q.messages[:valid?] = "Invalid tags, must contain only a-z, 0-9, and periods"
      end
    end

    def prompt_album_description
      return if group

      if prompt.yes?("Generate album description from YADG?")
        url = prompt.ask("Metadata URL:") do |q|
          q.required true
        end

        wizard.yadg.description(url)
      else
        prompt.multiline("Album description:") { |q| q.required true }
              .join
      end
    end

    def prompt_image_url_or_path
      return group.image if group&.image

      if prompt.yes?("Upload image from file within torrent?")
        local_image_path = prompt.select(
          "Select image file",
          wizard.non_audio_file_paths_map.map { |abs, rel| { name: rel.sub("#{wizard.path.basename}/", ""), value: abs } },
          filter: true,
        )

        if (images = wizard.ptpimg.upload([local_image_path.to_s]))
          images.first[1]
        else
          prompt.error "Network error uploading to ptpimg."
          nil
        end
      elsif prompt.yes?("Upload image from remote URL?")
        remote_image_url = prompt.ask("Remote image URL:") { |q| q.required true }

        if (images = wizard.ptpimg.upload_urls([remote_image_url]))
          images.first[1]
        else
          prompt.error "Network error uploading to ptpimg."
          nil
        end
      else
        prompt.warn "Continuing without an image."
        nil
      end
    end

    def prompt_release_description
      release_description = ""
      release_description_mutex = Mutex.new

      if (pre_description = prompt.multiline("Release description:"))
        release_description << pre_description.join
      end

      release_description << <<~DESCRIPTION

        This torrent was compiled by redacted_better v#{RedactedBetter::VERSION}, a script which helps automate uploads. This upload was not completed without the uploader's confirmation, and was not done unattended.

      DESCRIPTION

      include_mediainfo = prompt.yes?("Include per-track mediainfo output?")
      include_spectrals = prompt.yes?("Include per-track spectrograms?")

      if include_mediainfo || include_spectrals
        wizard.audio_files.each_with_index do |audio_file, i|
          release_description_mutex.synchronize do
            # SPOILER START
            release_description << <<~DESCRIPTION
              [hide="#{audio_file.path.basename}"]
            DESCRIPTION

            # MEDIAINFO
            release_description << <<~DESCRIPTION if include_mediainfo
              [quote][pre]#{`mediainfo "#{audio_file.path}"`.chomp}[/pre][/quote]
            DESCRIPTION

            # SPECTRAL
            release_description << "[img]{{spectral-#{i + 1}}}[/img]" if include_spectrals

            # SPOILER END
            release_description << <<~DESCRIPTION
              [/hide]
            DESCRIPTION
          end
        end
      end

      if include_spectrals
        spinners = TTY::Spinner::Multi.new("[:spinner] Generating spectrograms:")

        spectral_paths = []
        wizard.audio_files.each_with_index do |audio_file, i|
          spinners.register("[:spinner] #{File.basename audio_file.path}") do |sp|
            if (spectrogram = audio_file.spectrogram)
              spectral_paths << spectrogram

              spectral_template_tag = "{{spectral-#{i + 1}}}"

              release_description_mutex.synchronize do
                unless release_description.include?(spectral_template_tag)
                  spinner.error(Pastel.new.red("could not find tag in description: #{spectral_template_tag}"))
                end

                release_description.gsub!(spectral_template_tag, "{{spectral-#{spectrogram}}}")
              end

              sp.success(Pastel.new.green("done."))
            else
              spectral_paths << nil
              sp.error(Pastel.new.red("failed."))
            end
          end
        end
        spinners.auto_spin

        spinner = TTY::Spinner.new("[:spinner] Uploading to ptpimg...")
        spinner.auto_spin
        wizard.ptpimg
              .upload(spectral_paths)
              .each do |spectral_file_path, spectral_url|
          spectral_template_tag = "{{spectral-#{spectral_file_path}}}"

          release_description_mutex.synchronize do
            unless release_description.include?(spectral_template_tag)
              spinner.error(Pastel.new.red("could not find tag in description: #{spectral_template_tag}"))
            end

            release_description.gsub!(spectral_template_tag, spectral_url)
          end
        end

        spinner.success("done.")
      end

      final = sanitize_personal_paths(release_description).chomp

      if final.length >= 65_535
        prompt.warn("The generated release description exceeds 65,536 characters and will be truncated.")
      end

      final
    end

    # @param string [String]
    #
    # @return [String]
    def sanitize_personal_paths(string)
      string.gsub(wizard.config.fetch(:directories, :torrents), "/anon_torrents_dir")
            .gsub(wizard.config.fetch(:directories, :output), "/anon_output_dir")
            .gsub(wizard.config.fetch(:directories, :download), "/anon_download_dir")
            .gsub("taylorthurlow", "anon")
    end

    # @param group_id [String, Integer]
    #
    # @return [Group]
    def group_from_group_id(group_id)
      response = wizard.red_api.get(action: "torrentgroup", params: { id: group_id })

      Group.new(response.data.fetch("group"))
    end
  end
end
