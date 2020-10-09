require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.push_dir(File.expand_path("../lib", __dir__))
loader.setup

require "pry-byebug"

require "find"
require "json"

require "flacinfo"
require "htmlentities"
require "mechanize"

require "faraday"
require "pastel"
require "tty-config"
require "tty-file"
require "tty-prompt"
require "tty-spinner"

module RedactedBetter
  # @return [String]
  def self.user_agent
    "redacted_better/#{VERSION} (taylorthurlow/redacted_better@github)"
  end
end
