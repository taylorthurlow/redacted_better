class Account
  attr_reader :user_id, :cookie

  def initialize
    @username = nil
    @password = nil

    @cookie = nil
    @authkey = nil
    @passkey = nil
    @user_id = nil
  end

  def login
    auth_success = false
    until auth_success
      @username ||= find_username
      @password ||= find_password

      Log.info("Logging in as #{@username}... ", newline: false)

      conn = Faraday.new(url: "https://redacted.ch/")
      response = conn.post "login.php", username: @username, password: @password

      case response.status
      when 302
        Log.success("success!")
        auth_success = true
        @cookie = /session=[^;]*/.match(response.headers["set-cookie"])[0]
        set_user_info
      when 200
        Log.error("failure.")
        @username = prompt_username
        @password = prompt_password
      else
        Log.error("error code #{response.status}.")
        return false
      end
    end

    true
  rescue Faraday::TimeoutError
    Log.error("logging in timed out. Perhaps Redacted is down?")
    false
  end

  private

  def set_user_info
    response = Request.send_request(action: "index", cookie: @cookie)
    @authkey = response[:response]["authkey"]
    @passkey = response[:response]["passkey"]
    @user_id = response[:response]["id"]
  end

  def find_username
    $opts[:username] || $config.fetch(:username) || prompt_username
  end

  def find_password
    $opts[:password] || $config.fetch(:password) || prompt_password
  end

  def prompt_username
    TTY::Prompt.new.ask("Redacted username?", required: true, modify: :strip)
  end

  def prompt_password
    TTY::Prompt.new.ask("Redacted password?", required: true)
  end
end
