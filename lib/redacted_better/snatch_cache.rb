module RedactedBetter
  class SnatchCache
    # @param file_path [String] the cache file path
    # @param invalidate [Boolean] whether or not to invalidate the existing cache
    def initialize(file_path, invalidate)
      @file_path = file_path || default_cache_file
      FileUtils.rm(@file_path) if invalidate
      create_cache_file
    end

    # Adds a torrent to the cache.
    #
    # @param torrent [Torrent] the torrent to add to the cache
    #
    # @return [void]
    def add(torrent)
      data = JSON.parse(File.read(@file_path))

      data << {
        id: torrent.id,
        name: torrent.to_s,
      }

      File.open(@file_path, "w") do |f|
        f.truncate(0)
        f.puts data.to_json
      end
    end

    # Removes a torrent from the cache, if present.
    #
    # @param torrent [Torrent] the torrent to remove from the cache
    #
    # @return [Boolean] true if the removed torrent was present
    def remove(torrent)
      data = JSON.parse(File.read(@file_path))
      count_before = data.count

      data.delete_if do |entry|
        entry == {
          id: torrent.id,
          name: torrent.to_s,
        }
      end

      count_after = data.count

      File.open(@file_path, "w") do |f|
        f.truncate(0)
        f.puts data.to_json
      end

      count_before != count_after
    end

    # Determine if the cache contains a given torrent.
    #
    # @param torrent_id [Integer] the torrent id to search for in the cache
    #
    # @return [Boolean] true if the cache contains the torrent, false otherwise
    def contains?(torrent_id)
      JSON.parse(File.read(@file_path)).any? { |e| e["id"] == torrent_id }
    end

    private

    # The file path for the default cache file.
    def default_cache_file
      File.join(Config.config_directory, "cache.json")
    end

    # Create an empty cache file from a blank template, unless the file already
    # exists.
    #
    # @return [Boolean] true if the file was created, false if it was not
    def create_cache_file
      if File.exist? @file_path
        false
      else
        FileUtils.mkdir_p(File.dirname(@file_path))
        File.open(@file_path, "w") { |f| f.puts(template) }
        true
      end
    end

    # A blank template to write to new cache files.
    def template
      [].to_json
    end
  end
end
