class Account
  attr_reader :user_id, :cookie, :passkey

  # Creates a new instance of Account by performing a login to Redacted. Exits
  # the program if the login fails or encounters an error.
  def initialize
    exit unless login
  end

  private

  # Logs in to Redacted. The session cookie and passkey will be set on a
  # successful login.
  #
  # @return [Boolean] true if the login was successful, false otherwise
  def login
    username = find_username
    password = find_password

    Log.info("Logging in as #{username}... ", newline: false)

    conn = Faraday.new(url: "https://redacted.ch/")
    response = conn.post do |request|
      request.url "login.php"
      request.headers["User-Agent"] = RedactedBetter.user_agent
      request.body = { username: username, password: password }
    end

    handle_login_response(response)
  rescue Faraday::TimeoutError
    Log.error("Logging in timed out. Perhaps Redacted is down?")
    false
  end

  # Handles a login attempt response by delegating it to another handler based
  # on login success or failure.
  #
  # @param response [Faraday::Response] the response object from the login
  #
  # @return [Boolean] true if the login was successful, false otherwise
  def handle_login_response(response)
    case response.status
    when 302
      handle_successful_login(response)
      true
    when 200
      handle_failed_login
      false
    else
      handle_errored_login(response.status)
      false
    end
  end

  # Handles a successful login attempt by setting the session cookie.
  #
  # @param response [Faraday::Response] the response object from the login
  def handle_successful_login(response)
    Log.success("success!")
    @cookie = /session=[^;]*/.match(response.headers["set-cookie"])[0]
    set_user_info
  end

  # Handles a failed login attempt.
  def handle_failed_login
    Log.error("failure.")
  end

  # Handles an errored login attempt.
  def handle_errored_login(code)
    Log.error("error code #{code}.")
  end

  # Sends a request to obtain and store user information.
  def set_user_info
    response = Request.send_request_action(action: "index", cookie: @cookie)
    @authkey = response[:response]["authkey"]
    @passkey = response[:response]["passkey"]
    @user_id = response[:response]["id"]
  end

  # Obtains the user's username by first looking in the command options, then
  # in the config file. The user is prompted for the username if it was not
  # found.
  #
  # @return [String] the username
  def find_username
    $opts[:username] || $config.fetch(:username) || prompt_username
  end

  # Obtains the user's password by first looking in the command options, then
  # in the config file. The user is prompted for the password if it was not
  # found.
  #
  # @return [String] the password
  def find_password
    $opts[:password] || $config.fetch(:password) || prompt_password
  end

  # Prompts the user for a username.
  def prompt_username
    TTY::Prompt.new.ask("Redacted username?", required: true, modify: :strip)
  end

  # Prompts the user for a password.
  def prompt_password
    TTY::Prompt.new.mask("Redacted password?", required: true)
  end
end
