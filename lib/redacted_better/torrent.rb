module RedactedBetter
  class Torrent
    # @return [Integer]
    attr_accessor :id

    # @return [String]
    attr_accessor :media

    # @return [String]
    attr_accessor :format

    # @return [String]
    attr_accessor :encoding

    # @return [Boolean]
    attr_accessor :remastered

    # @return [Integer]
    attr_accessor :remaster_year

    # @return [String]
    attr_accessor :remaster_title

    # @return [String]
    attr_accessor :remaster_record_label

    # @return [String]
    attr_accessor :remaster_catalogue_number

    # @return [Boolean]
    attr_accessor :scene

    # @return [Array<String>]
    attr_accessor :file_list

    # @return [String, nil]
    attr_accessor :file_path

    # @return [Group]
    attr_accessor :group

    # @return [String]
    attr_accessor :download_directory

    # @param data_hash [Hash] the data hash which comes directly from the Redacted
    #   JSON API
    # @param group [Group] the torrent group to which this torrent belongs
    # @param download_directory [String] the path to the download directory
    def initialize(data_hash, group, download_directory)
      @group = group
      @id = data_hash["id"]
      @media = data_hash["media"]
      @format = data_hash["format"]
      @encoding = data_hash["encoding"]
      @remastered = data_hash["remastered"]
      @remaster_year = data_hash["remasterYear"]
      @remaster_title = data_hash["remasterTitle"]
      @remaster_record_label = data_hash["remasterRecordLabel"]
      @remaster_catalogue_number = data_hash["remasterCatalogueNumber"]
      @scene = data_hash["scene"]
      @file_path = data_hash["filePath"]
      @file_list = Torrent.parse_file_list(data_hash["fileList"])
      @download_directory = download_directory
    end

    # Determines the release year of the torrent.
    #
    # @return [Integer] The release year of the torrent. Some torrents may be
    #   remasters of an original release, in which case the torrent data
    #   contains the relevant information. If it is not a remaster, then the
    #   year must be determined by looking up the group's year instead.
    def year
      if remastered && !remaster_year.zero?
        remaster_year
      else
        group.year
      end
    end

    # A convenient string used to represent a torrent, particularly for use in
    # directory names.
    #
    # @return [String]
    def to_s
      Torrent.build_string(group.artist, group.name, year, media, format_shorthand)
    end

    # The Redacted URL for the torrent.
    #
    # @return [String]
    def url
      "https://redacted.ch/torrents.php?id=#{group.id}&torrentid=#{id}"
    end

    # Determines if there is a single all-encompassing folder at the root of the
    # torrent directory. Torrents which contain a single file (say, a music
    # single release) pollute the torrent download directory.
    #
    # @return [Boolean]
    def properly_contained?
      !file_path.empty?
    end

    # The list of absolute file paths in the torrent.
    #
    # @return [Array<String>]
    def files
      file_list.map { |f| File.join(download_directory, file_path, f) }
    end

    # The list of absolute file paths which represent files present on disk.
    #
    # @return [Array<String>]
    def files_present
      files.select { |f| File.exist?(f) }
    end

    # The list of absolute file paths which represent files missing on disk.
    #
    # @return [Array<String>]
    def files_missing
      files - files_present
    end

    # The list of absolute file paths representing flac files in the torrent.
    #
    # @return [Array<String>]
    def flac_files
      files.select { |f| File.extname(f).casecmp(".flac").zero? }
    end

    # The list of absolute file paths representing flac files with valid tags.
    #
    # @return [Array<String>]
    def flac_files_with_valid_tags
      raise "Cannot check for valid tags when some files are missing on disk." if files_missing.any?

      flac_files.select { |f| Tags.valid_tags?(f) }
    end

    # The list of absolute file paths representing flac files with invalid
    # tags.
    #
    # @return [Array<String>]
    def flac_files_with_invalid_tags
      flac_files - flac_files_with_valid_tags
    end

    # The list of absolute file paths representing flac files which contain
    # multichannel audio, meaning they have more than 2 channels.
    #
    # @return [Array<String>]
    def multichannel_files
      raise "Cannot check for multichannel files when some files are missing on disk." if files_missing.any?

      flac_files.select { |f| Transcode.file_is_multichannel?(f) }
    end

    # The list of absolute file paths representing flac files which are of a
    # bitrate higher than 16-bit, which typically means 24-bit.
    #
    # @return [Array<String>]
    def extreme_bitrate_files
      raise "Cannot check for extreme bitrate files when some files are missing on disk." if files_missing.any?

      flac_files.select { |f| Transcode.file_is_24bit?(f) }
    end

    # Determine if all FLAC files are of an extreme bitrate.
    #
    # @return [Boolean]
    def all_extreme_bitrate?
      flac_files.sort == extreme_bitrate_files.sort
    end

    # Determines if the torrent is mislabeled as 16-bit. Some torrents which
    # are **not** labeled as 24-bit are actually 24-bit, due to user error or
    # sometimes torrents which have a mix of both 24- and 16-bit files.
    #
    # @return [Boolean] true if all files are 24-bit but the torrent is not
    #   labeled as such, false otherwise
    def mislabeled_24bit?
      all_extreme_bitrate? && encoding != "24bit Lossless"
    end

    # @see .build_format
    def format_shorthand
      Torrent.build_format(format, encoding)
    end

    # Given a source torrent, a destination directory, and the format/encoding
    # of the transcode, generate a new .torrent file.
    #
    # Generates a `.torrent` file for a new torrent.
    #
    # @param output_directory [String] The root directory of the torrent. The
    #   directory itself will be included in the torrent to make sure that all
    #   files are properly encapsulated within a single directory, to prevent
    #   download directory pollution.
    # @param new_format [String]
    # @param new_encoding [String]
    # @param passkey [String] account passkey
    #
    # @return [String, nil] the path to the created torrent file, or nil if it
    #   was not created
    def make_torrent(output_directory, new_format, new_encoding, passkey)
      torrent_string = Torrent.build_string(
        group.artist,
        group.name,
        year,
        media,
        Torrent.build_format(new_format, new_encoding),
      )

      torrent_string += ".torrent"

      torrent_file = File.join(Dir.mktmpdir, torrent_string)

      # TODO : Allow config
      # mktorrent_exe = $config.fetch(:executables, :mktorrent) || "mktorrent"
      mktorrent_exe = "mktorrent"

      tracker_url = "https://flacsfor.me/#{passkey}/announce"
      `#{mktorrent_exe} -s RED -p -a #{tracker_url} -o "#{torrent_file}" -l 18 "#{output_directory}"`

      if $?.exitstatus.zero?
        torrent_file
      else
        nil
      end
    end

    # Determines if two torrents are members of the same release group.
    #
    # @param t1 [Torrent] the first torrent to compare
    # @param t2 [Torrent] the second torrent to compare
    #
    # @return [Boolean] true if they are in the same release group, false
    #   otherwise
    def self.in_same_release_group?(t1, t2)
      t1.media == t2.media &&
        t1.remaster_year == t2.remaster_year &&
        t1.remaster_title == t2.remaster_title &&
        t1.remaster_record_label == t2.remaster_record_label &&
        t1.remaster_catalogue_number == t2.remaster_catalogue_number
    end

    # A list of formats which are accepted as uploads to Redacted. Any format and
    # encoding combination not listed here is not allowed to be uploaded.
    def self.formats_accepted
      {
        "FLAC" => { format: "FLAC", encoding: "Lossless" },
        "320" => { format: "MP3", encoding: "320" },
        "V0" => { format: "MP3", encoding: "V0 (VBR)" },
      }
    end

    # A list of valid media sources which can be transcode sources.
    def self.valid_media
      %w[CD DVD Vinyl Soundboard SACD DAT Cassette WEB Blu-Ray]
    end

    # A list of valid media formats which can be uploaded.
    def self.valid_format
      %w[MP3 FLAC AAC AC3 DTS]
    end

    # A list of valid media encoding methods which can be uploaded.
    def self.valid_encoding
      [
        "192", "256", "320",
        "V0 (VBR)", "V1 (VBR)", "V2 (VBR)", "APS (VBR)", "APX (VBR)",
        "Lossless", "24bit Lossless",
        "Other",
      ]
    end

    # Builds a string which represents a given torrent's format and encoding
    # combination.
    #
    # @return [String] the string representing the format and encoding
    def self.build_format(format, encoding)
      case format
      when "FLAC"
        encoding.include?("24") ? "FLAC24" : "FLAC"
      when "MP3"
        case encoding
        when "320"
          "320"
        when "V0 (VBR)"
          "MP3v0"
        when "V2 (VBR)"
          "MP3v2"
        end
      else
        "#{format} #{encoding}"
      end
    end

    # (see #to_s)
    def self.build_string(artist, name, year, media, format)
      "#{artist} - #{name} (#{year}) [#{media} #{format}]"
    end

    # Parses the file list in the format provided by the Redacted JSON API. The
    # file path format given by the API needs some preprocessing in order to be
    # useful.
    #
    # @param raw_list [String] the raw file list directly from the JSON API
    #
    # @return [Array<String>] a list of file paths of all files in a torrent,
    #   relative to the root of the torrent. This root depends on whether or not
    #   the torrent is properly contained (see {#properly_contained?})
    def self.parse_file_list(raw_list)
      raw_list.gsub(/\|\|\|/, "")
              .split(/\{\{\{\d+\}\}\}/)
    end
  end
end
