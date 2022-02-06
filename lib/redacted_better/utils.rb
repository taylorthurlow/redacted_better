require "open3"

module RedactedBetter
  class Utils
    def self.deep_unescape_html(data)
      case data
      when Hash
        data.transform_values { |v| deep_unescape_html(v) }
      when Array
        data.map { |e| deep_unescape_html(e) }
      when String
        HTMLEntities.new.decode(data)
      else
        data
      end
    end

    # @param normalization_format [Symbol] one of the normalization format
    #   symbols accepted by String#unicode_normalize
    #
    # @return [String]
    def self.deep_unicode_normalize(data, normalization_format: :nfc)
      case data
      when Hash
        data.transform_values { |v| deep_unicode_normalize(v) }
      when Array
        data.map { |e| deep_unicode_normalize(e) }
      when String
        data.unicode_normalize(normalization_format)
      else
        data
      end
    end
  end
end
