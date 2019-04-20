require "fileutils"

require "factory_bot"
require "simplecov"
require "webmock/rspec"

unless ENV["NO_COVERAGE"]
  SimpleCov.start do
    add_filter "/vendor"
  end
end

require "bundler/setup"
Bundler.setup

require "redacted_better" # and any other gems you need

RSpec.configure do |config|
  # set up factory_bot
  config.include FactoryBot::Syntax::Methods

  # silence stdout and stderr
  original_stderr = $stderr
  original_stdout = $stdout

  config.before(:all) do
    unless defined?(Byebug) || defined?(Pry)
      $stderr = File.open(File::NULL, "w")
      $stdout = File.open(File::NULL, "w")
    end

    $opts = { config: "default_config.yaml" }
    $config = Config.load_config
  end

  config.after(:all) do
    $stderr = original_stderr
    $stdout = original_stdout
  end

  config.before(:each) do
    stub_request(:any, /redacted.ch/).to_rack(FakeRedacted)
  end

  config.before(:suite) do
    FactoryBot.find_definitions

    # Make sure we have a tmp folder to save random crap to
    FileUtils.mkdir_p "tmp"
  end

  # remove all temp files after suite finished
  config.after(:suite) do
    Dir["tmp/**/*"].each { |f| File.delete(f) }
  end
end

# allow rspec mocks in factory_bot definitions
FactoryBot::SyntaxRunner.class_eval do
  include RSpec::Mocks::ExampleMethods
end

Dir[File.dirname(__FILE__) + "/matchers/**/*.rb"].each { |file| require file }

#####
# Helper methods
#####

def generate_release_group
  group = create(:group)

  torrent = create(:torrent,
                   group: group,
                   media: "CD",
                   format: "FLAC",
                   encoding: "Lossless")

  { group: group, torrent: torrent }
end

def generate_file_list
  # 01 - Bluejuice - Video Games.flac{{{20972757}}}|||
  track = rand(1..100)
  artist = SecureRandom.hex(5)
  title = SecureRandom.hex(5)
  id = rand(1_000..1_000_000)
  "#{track} - #{artist} - #{title}.flac{{{#{id}}}}|||"
end
