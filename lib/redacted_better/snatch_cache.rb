class SnatchCache
  def initialize(file_path, invalidate)
    @file_path = file_path || default_cache_file
    FileUtils.rm(@file_path) if invalidate
    create_cache_file
  end

  # Adds a torrent to the cache.
  #
  # @param torrent [Torrent] the torrent to add to the cache
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
