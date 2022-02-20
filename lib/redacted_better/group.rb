module RedactedBetter
  class Group
    # @return [Integer]
    attr_accessor :id

    # @return [String]
    attr_accessor :name

    # @return [Integer]
    attr_accessor :year

    # @return [String]
    attr_accessor :record_label

    # @return [String]
    attr_accessor :catalogue_number

    # @return [Array<Hash>]
    attr_accessor :artists

    # @return [Integer]
    attr_accessor :release_type

    # @return [Integer]
    attr_accessor :category_id

    # @return [String]
    attr_accessor :category_name

    # @return [Boolean]
    attr_accessor :vanity_house

    # @return [String]
    attr_accessor :tags

    # @return [String]
    attr_accessor :image

    # @return [Array<Torrent>] the list of torrents within the group
    attr_accessor :torrents

    # @param data_hash [Hash] the data hash which comes directly from the Redacted
    #   JSON API
    def initialize(data_hash)
      data_hash = Utils.deep_unescape_html(data_hash)
      data_hash = Utils.deep_unicode_normalize(data_hash)

      @id = data_hash["id"]
      @name = data_hash["name"]
      @artists = data_hash["musicInfo"]["artists"]
      @year = data_hash["year"]
      @record_label = data_hash["recordLabel"]
      @catalogue_number = data_hash["catalogueNumber"]
      @release_type = data_hash["releaseType"]
      @category_id = data_hash["categoryId"]
      @category_name = data_hash["categoryName"]
      @vanity_house = data_hash["vanityHouse"]
      @tags = data_hash["tags"].join(",")
      @image = data_hash["wikiImage"]
      @torrents = []
    end

    # Determines the artist name based on the number of contributing artists.
    # Single artists are printed by themselves, two with a joining ampersand,
    # and more than two with just "Various Artists".
    #
    # @return [String] a string representing the artist(s) responsible for the
    #   group
    def artist
      case @artists.count
      when 1
        @artists.first["name"]
      when 2
        "#{@artists[0]["name"]} & #{@artists[1]["name"]}"
      else
        "Various Artists"
      end
    end

    # Sets the artist of a group to a single artist. Because the artists fields
    # supports more than one artist, it is worth noting that this method does not
    # support setting a value with more than one artist.
    #
    # @param new_artist [Hash] The artist information to add to the group,
    #   containing an Integer `id` and a String `name`. The hash can be in either
    #   string key or symbol key formats.
    def artist=(new_artist)
      @artists = [{
        "id" => new_artist[:id] || new_artist["id"],
        "name" => new_artist[:name] || new_artist["name"],
      }]
    end

    # Determines which formats are missing from a torrent by calculating which
    # torrents are present within a group, and using a list of accepted formats
    # to find which are missing.
    #
    # @param torrent [Torrent] The torrent to identify which release group we
    #   are looking to query. A group may contain many release groups, and we
    #   need one torrent from that group to find the specific release group.
    #
    # @return [Array(String, String)] A list of format/encoding pairs
    #   representing all formats missing from the release group.
    def formats_missing(torrent)
      present = release_group_torrents(torrent).map { |t| [t.format, t.encoding] }

      Torrent.formats_accepted
             .values
             .map(&:values)
             .reject { |f| present.include? f }
    end

    private

    # Given a torrent in a release group, find all torrents in the group which
    # are in the same release group. The returned list will also include the
    # torrent used to identify the release group.
    #
    # @param torrent [Torrent] the torrent used to identify the release group
    #
    # @return [Array<String, String>] a list of format/encoding pairs representing
    #   all formats in the release group
    def release_group_torrents(torrent)
      torrents.select { |t| Torrent.in_same_release_group?(t, torrent) }
    end
  end
end
