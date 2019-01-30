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

      if tag_name == 'TRACKNUMBER' && !valid_track_tag?(tags['TRACKNUMBER'])
        errors << [basename, 'Malformed track number tag.']
        next
      end
    end

    { valid: errors.none?, errors: errors }
  end

  private_class_method def self.valid_track_tag?(tag)
    /^[A-Za-z]?\d+$/ =~ tag
  end
end