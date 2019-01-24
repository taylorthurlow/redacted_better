class Request
  @@rate_limit = 2.0 # minimum seconds between each request
  @@last_request_time = Time.now.to_f

  def self.send_request(action:, cookie:, params: {})
    wait_for_request

    response = Faraday.new(url: 'https://redacted.ch/').get do |request|
      url = "ajax.php?action=#{action}"
      params.each { |p, v| url += "&#{p}=#{v}" }
      request.url url
      request.headers = action_headers('Cookie' => cookie)
    end

    notify_request_sent

    data = JSON.parse(response.body)

    {
      code: response.status,
      status: data['status'],
      response: data['response']
    }
  end

  def self.wait_for_request
    sleep(0.1) while seconds_since_last_request < @@rate_limit
  end

  def self.notify_request_sent
    @@last_request_time = Time.now.to_f
  end

  def self.seconds_since_last_request
    Time.now.to_f - @@last_request_time
  end

  # these headers are generally applicable to any requests being made by
  # redacted_better, whether they are JSON API requests or just requests for
  # HTML page contents.
  def self.headers(params = {})
    {
      'User-Agent' => "redacted_better/#{RedactedBetter::VERSION} "\
                      '(github.com/taylorthurlow/redacted_better)'
    }.merge(params)
  end

  # these headers are only applicable to requests to the official JSON api,
  # which all are in the form of "ajax.php?action=". Using these headers will
  # break responses to requests which are expected to be in HTML format like
  # "torrents.php".
  def self.action_headers(params = {})
    headers.merge(
      'Cache-Control' => 'max-age=0',
      'Connection' => 'keep-alive',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding' => 'gzip,deflate,sdch',
      'Accept-Language' => 'en-US,en;q=0.8',
      'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.3'
    ).merge(params)
  end
end
