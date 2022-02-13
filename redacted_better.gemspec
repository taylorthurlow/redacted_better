$LOAD_PATH << File.expand_path("lib", __dir__)
require "redacted_better/version"

Gem::Specification.new do |s|
  s.name = "redacted_better"
  s.version = RedactedBetter::VERSION
  s.license = "MIT"
  s.summary = "Automatically upload transcodes that Redacted is missing."
  s.description = "Automatically search your Redacted downloads for opportunities to upload transcodes."
  s.author = "Taylor Thurlow"
  s.email = "taylorthurlow@me.com"
  s.files = Dir["{bin,lib}/**/*"]
  s.homepage = "https://github.com/taylorthurlow/redacted_better"
  s.executables = ["redactedbetter"]
  s.platform = "ruby"
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 2.6"

  s.add_dependency "faraday", "~> 1.0.1"      # HTTP client
  s.add_dependency "flacinfo-rb", "~> 1.0"    # Inspect FLAC metadata/info
  s.add_dependency "htmlentities", "~> 4.3"   # Encode/decode HTML entities
  s.add_dependency "mechanize", "~> 2.7"      # Automated web interaction
  s.add_dependency "mediainfo", "~> 1.5.0"
  s.add_dependency "os", "~> 1.1.4"
  s.add_dependency "pastel", "~> 0.7"         # Print to STDOUT with colors
  s.add_dependency "require_all", "~> 2.0"    # Easy require statements
  s.add_dependency "ruby-mp3info", "~> 0.8"   # Manage MP3 metadata
  s.add_dependency "slop", "~> 4.8.2"         # Command line parameters/flags
  s.add_dependency "tty-config", "~> 0.4"     # Config file management
  s.add_dependency "tty-file", "~> 0.10"      # Filesystem management
  s.add_dependency "tty-prompt", "~> 0.22"    # Easy prompts
  s.add_dependency "tty-spinner", "~> 0.9"    # Cool looking loading spinners
  s.add_dependency "zeitwerk", "~> 2.0"       # Code loading

  s.add_development_dependency "factory_bot", "~> 6.0" # Easy test fixtures
  s.add_development_dependency "guard", "~> 2.15"       # File watcher
  s.add_development_dependency "guard-rspec", "~> 4.7"
  s.add_development_dependency "rspec", "~> 3.8"        # Test suite
  s.add_development_dependency "simplecov", "~> 0.16"   # Code coverage
  s.add_development_dependency "sinatra", "~> 2.0"      # API stubbing
  s.add_development_dependency "wavefile", "~> 1.1"     # Audio generator
  s.add_development_dependency "webmock", "~> 3.5"      # Web stubbing
end
