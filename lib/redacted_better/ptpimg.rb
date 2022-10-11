module RedactedBetter
  class Ptpimg
    # @param api_key [String]
    def initialize(api_key)
      @api_key = api_key
    end

    # @param file_paths [Array<String>]
    #
    # @return [Hash{String=>String}, nil] keys are original provided path, value
    #   is new URL - or nil if network issue encountered
    def upload(file_paths)
      connection = Faraday.new(url: "https://ptpimg.me") do |f|
        f.request :multipart
        f.use Faraday::Response::RaiseError
      end

      response = connection.post(
        "/upload.php",
        "file-upload" => file_paths.map { |path| Faraday::FilePart.new(path, "image/#{File.extname(path)[1..]}") },
        "api_key" => @api_key,
      )

      i = -1
      JSON.parse(response.body)
          .to_h do |e|
        i += 1
        [file_paths[i], "https://ptpimg.me/#{e.fetch("code")}.#{e.fetch("ext")}"]
      end
    end

    # @param file_paths [Array<String>]
    #
    # @return [Hash{String=>String}, nil] keys are original provided path, value
    #   is new URL - or nil if network issue encountered
    def upload_urls(urls)
      connection = Faraday.new(url: "https://ptpimg.me") do |f|
        f.request :multipart
        f.use Faraday::Response::RaiseError
      end

      response = connection.post(
        "/upload.php",
        "link-upload" => Faraday::ParamPart.new(urls.map(&:strip).join("\n"), "text/plain"),
        # "link-upload" => urls.map(&:strip).join("\n"),
        "api_key" => Faraday::ParamPart.new(@api_key, "text/plain"),
        # "api_key" => @api_key,
      )

      i = -1
      JSON.parse(response.body)
          .to_h do |e|
        i += 1
        [urls[i], "https://ptpimg.me/#{e.fetch("code")}.#{e.fetch("ext")}"]
      end
    rescue Faraday::ServerError, Faraday::ClientError => e
      require "pry-byebug"
      binding.pry

      nil
    end
  end
end
