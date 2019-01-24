class Account
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

      conn = Faraday.new(url: 'https://redacted.ch/')
      response = conn.post 'login.php', username: @username, password: @password

      case response.status
      when 302
        puts Pastel.new.green("Authorization of user #{@username} successful.")
        auth_success = true
        @cookie = /session=[^;]*/.match(response.headers['set-cookie'])[0]
        set_user_info
      when 200
        puts Pastel.new.red('Authorization failed. Try again.')
        @username = prompt_username
        @password = prompt_password
      else
        puts Pastel.new.red("Something went wrong - code #{response.status}")
        exit
      end
    end
  end

  private

  def set_user_info
    response = Request.send(action: 'index', cookie: @cookie)
    @authkey = response['response']['authkey']
    @passkey = response['response']['passkey']
    @user_id = response['response']['id']
  end

  def find_username
    $opts[:username] || $config.fetch(:username) || prompt_username
  end

  def find_password
    $opts[:password] || $config.fetch(:password) || prompt_password
  end

  def prompt_username
    TTY::Prompt.new.ask('Redacted username?', required: true, modify: :strip)
  end

  def prompt_password
    TTY::Prompt.new.ask('Redacted password?', required: true)
  end
end
