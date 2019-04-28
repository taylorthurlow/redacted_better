class Account
  attr_reader :user_id, :cookie, :passkey

  def initialize
    @username = nil
    @password = nil

    @cookie = nil
    @authkey = nil
    @passkey = nil
    @user_id = nil
  end

  def login
    @username ||= find_username
    @password ||= find_password

    Log.info("Logging in as #{@username}... ", newline: false)

    conn = Faraday.new(url: "https://redacted.ch/")
    response = conn.post do |request|
      request.url "login.php"
      request.headers["User-Agent"] = RedactedBetter.user_agent
      request.body = { username: @username, password: @password }
    end

    case response.status
    when 302
      handle_successful_login(response)
      return true
    when 200
      handle_failed_login
      return false
    else
      handle_errored_login(response.status)
      return false
    end
  rescue Faraday::TimeoutError
    Log.error("Logging in timed out. Perhaps Redacted is down?")
    false
  end

  private

  def handle_successful_login(response)
    Log.success("success!")
    @cookie = /session=[^;]*/.match(response.headers["set-cookie"])[0]
    set_user_info
  end

  def handle_failed_login
    Log.error("failure.")
  end

  def handle_errored_login(code)
    Log.error("error code #{code}.")
  end

  def set_user_info
    response = Request.send_request_action(action: "index", cookie: @cookie)
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
    TTY::Prompt.new.mask("Redacted password?", required: true)
  end
end
