require "mp3info"

module RedactedBetter
  class Tags
    # Determines whether or not the tags of the provided media file are valid or
    # not. Accepts both FLAC and MP3 files.
    def self.valid_tags?(file_path)
      case File.extname(file_path).downcase
      when ".flac"
        valid_flac_tags?(file_path)
      when ".mp3"
        valid_mp3_tags?(file_path)
      else
        raise "Unable to check for valid tags on file with an unknown extension."
      end
    end

    # Copies all relevant file tags from an input FLAC file to a destination FLAC
    # or MP3 file, given the absolute file paths to each.
    def self.copy_tags(source, destination)
      case File.extname(destination).downcase
      when ".flac"
        result = copy_tags_to_flac(source, destination)
      when ".mp3"
        result = copy_tags_to_mp3(source, destination)
      else
        raise "Tried to copy tags to a destination with an unknown file extension."
      end

      check_tags_equal(source, destination)

      result
    end

    private

    # Determines if all relevant file tags of a source and destination audio file
    # are the same. Used to check that a tag copy happened successfully.
    #
    # @param source [FlacInfo]
    # @param destination [FlacInfo]
    #
    # @return [Boolean] true if equal
    def self.check_tags_equal(source, destination)
      true # TODO: Implement this
    end

    # Copies all relevant file tags given a source and destination instance of
    # FlacInfo.
    #
    # @param source [FlacInfo]
    # @param destination [FlacInfo]
    #
    # @return [Boolean] true if set successfully, false otherwise
    def self.copy_tags_to_flac(source, destination)
      source = FlacInfo.new(source)
      destination = FlacInfo.new(destination)

      source.tags.each do |name, value|
        next unless allowed_tags.include? name

        destination.comment_add("#{name}=#{value}")
      end

      destination.update!
    rescue FlacInfoError, FlacInfoReadError, FlacInfoWriteError => e
      Log.error("  Error reading/writing FLAC: #{e.inspect}")
      false
    end

    # Copies all relevant file tags from a FLAC file to an MP3 file, given the
    # absolute file paths to each. Returns true if the tags were set
    # successfully, and false otherwise.
    def self.copy_tags_to_mp3(source, destination)
      source = FlacInfo.new(source)
      destination = Mp3Info.open(destination)

      source.tags.each do |name, value|
        next unless (tag_methods = mp3_tag_methods[name]) # Skip if not accepted tag
        next unless value # Skip unless the tag has a value

        value = value.force_encoding("UTF-8")
        var_to_set = (tag_methods[1].to_s + "=").to_sym
        destination.send(tag_methods[0]).send(var_to_set, value)
      end

      destination.close
      true
    rescue FlacInfoError, FlacInfoReadError, FlacInfoWriteError => e
      Log.error("  Error reading/writing FLAC: #{e.inspect}")
      false
    rescue Mp3InfoError => e
      Log.error("  Problem reading/writing MP3: #{e.inspect}")
      false
    rescue TypeError => e
      Log.error("  Problem reading/writing file: #{e.inspect}")
    end

    # Determines whether or not the tags on a given FLAC file are valid with
    # regards to Redacted's tagging rules.
    def self.valid_flac_tags?(file_path)
      errors = flac_tag_errors(file_path)
      errors.each { |file, message| Log.error("  #{file}: #{message}") }
      errors.empty?
    end

    # Determines whether or not the tags on a given MP3 file are valid with
    # regards to Redacted's tagging rules.
    def self.valid_mp3_tags?(file_path)
      errors = mp3_tag_errors(file_path)
      errors.each { |file, message| Log.error("  #{file}: #{message}") }
      errors.empty?
    end

    # Compiles a list of all problems with the tags of a given FLAC file.
    def self.flac_tag_errors(file_path)
      errors = []
      basename = File.basename(file_path)
      tags = FlacInfo.new(file_path)
                     .tags
                     .transform_keys { |k| k.upcase }

      required_tags.each do |tag_name|
        unless tags.key? tag_name
          errors << [basename, "Missing #{tag_name.downcase} tag."]
          next
        end

        if tags[tag_name].empty?
          errors << [basename, "Blank #{tag_name.downcase} tag."]
          next
        end

        if tag_name == "TRACKNUMBER" && !valid_track_tag?(tags["TRACKNUMBER"])
          errors << [basename, "Malformed track number tag."]
          next
        end
      end

      errors
    rescue FlacInfoError, FlacInfoReadError, FlacInfoWriteError => e
      Log.error("  Error reading/writing FLAC: #{e.inspect}")
      false
    end

    # Compiles a list of all problems with the tags of a given MP3 file.
    def self.mp3_tag_errors(file_path)
      errors = []
      basename = File.basename(file_path)
      info = Mp3Info.open(file_path)

      required_tags.each do |tag_name|
        tag = info.tag.send(mp3_tag_methods[tag_name].to_sym)

        unless tag
          errors << [basename, "Missing #{tag_name.downcase} tag."]
          next
        end

        if tag.strip.empty?
          errors << [basename, "Blank #{tag_name.downcase} tag."]
          next
        end

        if tag_name == "TRACKNUMBER" && !valid_track_tag?(tag)
          errors << [basename, "Malformed track number tag."]
          next
        end
      end

      errors
    rescue Mp3InfoError => e
      Log.error("  Problem reading/writing MP3: #{e.inspect}")
      false
    end

    def self.valid_track_tag?(tag)
      /^[A-Za-z]?\d+$/ =~ tag
    end

    def self.required_tags
      ["TITLE", "ARTIST", "ALBUM", "TRACKNUMBER"]
    end

    def self.allowed_tags
      required_tags + ["YEAR", "GENRE", "COMMENTS"]
    end

    def self.mp3_tag_methods
      {
        "TITLE" => [:tag, :title],
        "ARTIST" => [:tag, :artist],
        "ALBUM" => [:tag, :album],
        "TRACKNUMBER" => [:tag2, :TRCK],
        "YEAR" => [:tag2, :TYER],
        "DATE" => [:tag2, :TDAT],
        "GENRE" => [:tag, :genre_s],
        "COMMENTS" => [:tag, :comments],
      }
    end
  end
end
