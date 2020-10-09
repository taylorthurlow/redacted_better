require "json"

module RedactedBetter
  class Response
    # @return [Integer]
    attr_reader :code

    # @return [String]
    attr_reader :status

    # @return [Hash{String=>Object}]
    attr_reader :data

    # @param code [Integer] the HTTP status code
    # @param body [String] the JSON response body
    def initialize(code:, body:)
      @code = code

      begin
        parsed_body = JSON.parse(body)
      rescue JSON::ParserError
        @data = {}
        @status = "unknown"
      end

      @data = parsed_body["response"] || parsed_body["error"]
      @status = parsed_body["status"]
    end

    # @return [Boolean]
    def success?
      @status.casecmp("success").zero?
    end

    # @return [Boolean]
    def failure?
      !success?
    end
  end
end
