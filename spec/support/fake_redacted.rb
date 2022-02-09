require "sinatra/base"

class FakeRedacted < Sinatra::Base
  set :environment, :test

  post "/login.php" do
    status 302
    headers "Set-Cookie" => "session=asdf1234; path=/; secure; HttpOnly"
  end

  get "/torrents.php" do
    if edit_torrent_params_get
      status 200
      if params["should_fail"]
        response_file("torrent_edit_403.html")
      else
        response_file("torrent_edit_success.html")
      end
    else
      raise "Unknown parameters for torrents.php request"
    end
  end

  post "/torrents.php" do
    if edit_torrent_params_post
      status(params["should_fail"] ? 500 : 200)
    else
      raise "Unknown parameters for torrents.php request"
    end
  end

  ajax_action_parameters = {
    "index" => [],
    "torrentgroup" => [:id],
  }

  get "/ajax.php" do
    action = params["action"]

    missing_params = ajax_action_parameters[action].reject do |param|
      params[param.to_s]
    end

    raise "Missing parameter(s): #{missing_params.join(", ")}" if missing_params.any?

    action_json_response 200, action
  end

  private

  def edit_torrent_params_get
    params["action"] == "edit" && params["id"]
  end

  def edit_torrent_params_post
    params["action"] == "takeedit" && params["torrentid"]
  end

  def user_snatched_flacs_params
    params["type"] == "snatched" && params["userid"] && params["format"] == "FLAC" && params["page"]
  end

  def action_json_response(response_code, action)
    content_type :json
    status response_code
    response_file(action + ".json")
  end

  def response_file(*pieces)
    root = File.dirname(__FILE__)
    path = File.join(root, "redacted_responses", File.join(pieces))
    File.open(path)
  end
end
