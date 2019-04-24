class Utils
  def self.deep_unescape_html(data)
    case data
    when Hash
      data.map { |k, v| [k, deep_unescape_html(v)] }.to_h
    when Array
      data.map { |e| deep_unescape_html(e) }
    when String
      HTMLEntities.new.decode(data)
    else
      data
    end
  end
end
