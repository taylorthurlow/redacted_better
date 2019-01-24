class Request
  @@rate_limit = 2.0 # minimum seconds between each request
  @@last_request_time = Time.now.to_f

  def self.send_request(action, cookie, params = {})
    sleep(0.1) while seconds_since_last_request < @@rate_limit

    response = Faraday.new(url: 'https://redacted.ch/').get do |request|
      url = "ajax.php?action=#{action}"
      params.each { |p, v| url += "&#{p}=#{v}" }
      request.url url
      request.headers = headers.merge('Cookie' => cookie)
    end

    data = JSON.parse(response.body)

    {
      code: response.status,
      status: data['status'],
      response: data['response']
    }
  end

  def self.seconds_since_last_request
    Time.now.to_f - @@last_request_time
  end

  def self.headers
    {
      'Connection' => 'keep-alive',
      'Cache-Control' => 'max-age=0',
      'User-Agent' => 'taylorthurlow/redacted_better',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding' => 'gzip,deflate,sdch',
      'Accept-Language' => 'en-US,en;q=0.8',
      'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.3'
    }
  end
end
