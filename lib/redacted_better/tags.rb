require "mp3info"
require "open3"

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
    #
    # @parm source [String]
    # @parm destination [String]
    #
    # @return [Array<String>] errors that occurred, if any
    def self.copy_tags(source, destination)
      case File.extname(destination).downcase
      when ".flac"
        copy_tags_to_flac(source, destination)
      when ".mp3"
        copy_tags_to_mp3(source, destination)
      else
        raise "Tried to copy tags to a destination with an unknown file extension."
      end
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

    # Destructively copies all tags from one FLAC to another.
    #
    # @param source [String]
    # @param destination [String]
    #
    # @return [Array<String>] errors that occurred, if any
    def self.copy_tags_to_flac(source, destination)
      errors = []

      # Save tags to a file because piping them back into metaflac causes issues
      # with tags that have newlines.
      temp_tags_file = File.join(Dir.mktmpdir, File.basename(source))
      export_command = "metaflac --no-utf8-convert --export-tags-to=\"#{temp_tags_file}\" \"#{source}\""

      _stdout, stderr, status = Open3.capture3(export_command)

      errors << "Exit code #{status.exitstatus}" unless status.success?
      errors << stderr.tr("\n", " ") unless stderr.nil? || stderr.empty?

      return errors if errors.any?

      # This routine takes an existing tags file, which consists of KEY=VALUE
      # pairs, and removes any key value pair that spans multiple lines. This is
      # because loading tags back into the new FLAC file with `metaflac` is
      # currently broken when trying to load multi-line tags.
      # GH issue: https://github.com/xiph/flac/issues/232
      new_tags_file_path = begin
          file = Tempfile.new("tags")
          source_tags_lines = File.readlines(temp_tags_file)

          source_tags_lines.each_with_index do |line, i|
            current_line_has_equal = line.include?("=")
            next_line_exists = !source_tags_lines[i + 1].nil?

            if next_line_exists
              next_line = source_tags_lines[i + 1]
              next_line_has_equal = next_line.include?("=")

              if current_line_has_equal && next_line_has_equal
                file.write(line)
              elsif current_line_has_equal && !next_line_has_equal
                next
              end
            elsif current_line_has_equal
              file.write(line)
            end
          end

          file.path
        ensure
          file&.close
        end

      import_command = "metaflac --remove-all-tags --import-tags-from=\"#{new_tags_file_path}\" \"#{destination}\""

      _stdout, stderr, status = Open3.capture3(import_command)

      errors << "Exit code #{status.exitstatus}" unless status.success?
      errors << stderr.tr("\n", " ") unless stderr.nil? || stderr.empty?

      errors
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

      []
    rescue FlacInfoError, FlacInfoReadError, FlacInfoWriteError => e
      ["Error reading/writing FLAC: #{e.inspect}"]
    rescue Mp3InfoError => e
      ["Problem reading/writing MP3: #{e.inspect}"]
    rescue TypeError => e
      ["Problem reading/writing file: #{e.inspect}"]
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
      ["Error reading/writing FLAC: #{e.inspect}"]
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
      ["Problem reading/writing MP3: #{e.inspect}"]
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
