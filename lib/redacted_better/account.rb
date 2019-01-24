class Account
  def initialize(username:, password:)
    @username = username
    @password = password
  end

  def login
    page = 'https://redacted.ch/'
    conn = Faraday.new(url: page)
    conn.post 'login.php', username: @username, password: @password
  end
end
