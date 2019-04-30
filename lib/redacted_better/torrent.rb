class Torrent
  attr_accessor :id, :media, :format, :encoding, :remastered, :remaster_year,
    :remaster_title, :remaster_record_label, :remaster_catalogue_number,
    :file_list, :file_path, :group

  # @param data_hash [Hash] the data hash which comes directly from the Redacted
  #   JSON API
  # @param group [Group] the torrent group to which this torrent belongs
  def initialize(data_hash, group)
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
    @file_path = data_hash["filePath"]
    @file_list = Torrent.parse_file_list(data_hash["fileList"],
                                         data_hash["filePath"])
  end

  # Determines if there is a single all-encompassing folder at the root of the
  # torrent directory. Torrents which contain a single file (say, a music
  # single release) pollute the torrent download directory.
  #
  # @return [Boolean] true if there is a single root folder, false otherwise
  def properly_contained?
    !@file_path.empty?
  end

  # Determines if every file contained within the torrent (music and otherwise)
  # is present in the proper location on the disk.
  #
  # @param flacs_only [Boolean] when true, performs the same lookup but only
  #   for all FLAC files.
  #
  # @return [Boolean] true if all files are found on disk, false otherwise
  def on_disk?(flacs_only: false)
    files = flacs_only ? flacs : @file_list
    files.all? { |f| File.exist?(f) }
  end

  # A list of all files within the torrent with a FLAC extension.
  #
  # @return [Array<String>] the file paths of each file
  def flacs
    @file_list.select { |f| File.extname(f).casecmp(".flac").zero? }
  end

  # Determines if every FLAC file contained within the torrent has a bit depth
  # of *at least* 24 bits.
  #
  # @return [Boolean] true if all are at least 24-bit, false otherwise
  def all_24bit?
    on_disk?(flacs_only: true) && flacs.all? { |f| Transcode.file_is_24bit?(f) }
  end

  # Determines if the torrent is mislabeled as 16-bit. Some torrents which are
  # **not** labeled as 24-bit are actually 24-bit, due to user error or
  # sometimes torrents which have a mix of both 24- and 16-bit files.
  #
  # @return [Boolean] true if all files are 24-bit but the torrent is not
  #   labeled as such, false otherwise
  def mislabeled_24bit?
    all_24bit? && @encoding != "24bit Lossless"
  end

  # Determines if any of the FLAC files within the torrent are multichannel
  # files, meaning they have more than 2 channels. These files are not
  # supported in any way by redacted_better.
  #
  # @return [Boolean] true if all files have 2 or fewer channels, false
  #   otherwise
  def any_multichannel?
    on_disk?(flacs_only: true) && flacs.any? { |f| Transcode.file_is_multichannel?(f) }
  end

  # Determines the release year of the torrent.
  #
  # @return [Integer] The release year of the torrent. Some torrents may be
  #   remasters of an original release, in which case the torrent data contains
  #   the relevant information. If it is not a remaster, then the year must be
  #   determined by looking up the group's year instead.
  def year
    if @remastered && !@remaster_year.zero?
      @remaster_year
    else
      @group.year
    end
  end

  # A convenient string used to represent a torrent, particularly for use in
  # directory names.
  def to_s
    Torrent.build_string(@group.artist, @group.name, year, @media, format_shorthand)
  end

  # The Redacted URL for the torrent.
  def url
    "https://redacted.ch/torrents.php?id=#{@group.id}&torrentid=#{@id}"
  end

  # Determines which files are missing on the disk.
  #
  # @return [Array<String>] the list of basenames of files which are missing on
  #   disk
  def missing_files
    @file_list.reject { |f| File.exist?(f) }
              .map { |f| File.basename(f) }
  end

  # Determines if all FLAC files have valid tags.
  #
  # @return [Boolean] true if all files have valid tags, false otherwise
  def valid_tags?
    on_disk?(flacs_only: true) && flacs.all? { |f| Tags.valid_tags?(f) }
  end

  # @see .build_format
  def format_shorthand
    Torrent.build_format(@format, @encoding)
  end

  # Given a source torrent, a destination directory, and the format/encoding of
  # the transcode, generate a new .torrent file.
  #
  # Generates a `.torrent` file for a new torrent.
  #
  # @param format [String] the format of the newly transcoded files
  # @param encoding [String] the encoding of the newly transcoded files
  # @param directory [String] The root directory of the torrent. The directory
  #   itself will be included in the torrent to make sure that all files are
  #   properly encapsulated within a single directory, to prevent download
  #   directory pollution.
  #
  # @return [Boolean] true if the torrent creation succeeded, false otherwise
  def make_torrent(format, encoding, directory)
    torrent_string = Torrent.build_string(group.artist, group.name, year, media,
                                          Torrent.build_format(format, encoding))
    torrent_string += ".torrent"

    torrent_file_dir = $config.fetch(:directories, :torrents)
    FileUtils.mkdir_p(torrent_file_dir)
    torrent_file = File.join(torrent_file_dir, torrent_string)

    mktorrent_exe = $config.fetch(:executables, :mktorrent) || "mktorrent"
    tracker_url = "https://flacsfor.me/#{$account.passkey}/announce"
    `#{mktorrent_exe} -s RED -p -a #{tracker_url} -o "#{torrent_file}" -l 18 "#{directory}"`

    $?.exitstatus.zero?
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
  # @param root_path [String] the path of the torrent, relative to the
  #   configured torrent download directory
  #
  # @return [Array<String>] a list of file paths of all files in a torrent,
  #   relative to the root of the torrent. This root depends on whether or not
  #   the torrent is properly contained (see {#properly_contained?})
  def self.parse_file_list(raw_list, root_path)
    path = File.join($config.fetch(:directories, :download), root_path)
    raw_list.gsub(/\|\|\|/, "")
            .split(/\{\{\{\d+\}\}\}/)
            .map { |p| File.join(path, p) }
  end
end
