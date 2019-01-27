class Tags
  def self.valid_tags?(file)
    errors = []
    tags = FlacInfo.new(file).tags
    required_tags = ['ARTIST', 'ALBUM', 'TITLE', 'TRACKNUMBER']

    required_tags.each do |tag_name|
      basename = File.basename(file)

      unless tags.key? tag_name
        errors << [basename, "Missing #{tag_name.downcase} tag."]
        next
      end

      if tags[tag_name].empty?
        errors << [basename, "Blank #{tag_name.downcase} tag."]
        next
      end

      unless valid_track_tag?(tags['TRACKNUMBER'])
        errors << [basename, 'Malformed track number tag.']
        next
      end
    end

    { valid: errors.none?, errors: errors }
  end

  def self.all_valid_tags?(files)
    results = files.select { |f| File.extname(f) == '.flac' }
                   .map { |f| valid_tags?(f) }

    {
      valid: results.all? { |r| r[:valid] },
      errors: results.map { |r| r[:errors] }.flatten
    }
  end

  def self.valid_track_tag?(tag)
    /^[A-Za-z]?\d+$/ =~ tag
  end
end
