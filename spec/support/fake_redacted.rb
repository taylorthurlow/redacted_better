require "sinatra/base"

class FakeRedacted < Sinatra::Base
  post "/login.php" do
    status 302
    headers "Set-Cookie" => "session=asdf1234; path=/; secure; HttpOnly"
  end

  ajax_action_parameters = {
    "index" => [],
    "torrentgroup" => [:id],
  }

  get "/ajax.php" do
    action = params["action"]

    unless ajax_action_parameters.key? action
      raise "sent GET to /ajax.php without valid action parameter"
    end

    missing_params = ajax_action_parameters[action].reject do |param|
      params[param.to_s]
    end

    raise "missing parameter(s): #{missing_params.join(", ")}" if missing_params.any?

    action_json_response 200, action
  end

  private

  def action_json_response(response_code, action)
    content_type :json
    status response_code
    File.open(File.dirname(__FILE__) + "/redacted_responses/" + action + ".json", "rb")
  end
end
