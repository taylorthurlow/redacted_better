class SnatchCache
  def initialize(cache_path, invalidate)
    # Has the user supplied an alternate cache file?
    @file = cache_path || File.join(Config.config_directory, "cache.json")

    File.delete(@file) if invalidate

    # Create the file with a default JSON template if it doesnt exist
    File.open(@file, "w") { |f| f.puts(template) } unless File.exist? @file
  end

  # Adds a torrent to the cache.
  def add(torrent)
    data = JSON.parse(File.read(@file))
    data << {
      id: torrent.id,
      name: torrent.to_s,
    }

    File.open(@file, "w") do |f|
      f.truncate(0)
      f.puts data.to_json
    end
  end

  # Determine if the cache contains a given torrent.
  def contains?(torrent_id)
    JSON.parse(File.read(@file)).any? { |e| e["id"] == torrent_id }
  end

  private

  def template
    [].to_json
  end
end
