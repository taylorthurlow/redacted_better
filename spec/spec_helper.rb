require "fileutils"

require "factory_bot"
require "simplecov"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

# Don't start code coverage if an environment variable is set, or if we are
# explicitly testing a particular file/files. We only want to run coverage
# reports when we run the entire test suite.
if !ENV["NO_COVERAGE"] && ARGV.grep(/spec\.rb/).empty?
  SimpleCov.start do
    add_filter do |source_file|
      (source_file.project_filename =~ /^\/lib\//).nil?
    end
  end
end

require "bundler/setup"
Bundler.setup

require "redacted_better"

# Check if sox is installed
`which sox`
unless $?.success?
  warn "Unable to find `sox` executable."
  exit 1
end

RSpec.configure do |config|
  # Set up factory_bot
  config.include FactoryBot::Syntax::Methods

  # Silence stdout and stderr
  original_stderr = $stderr
  original_stdout = $stdout

  config.before(:all) do
    # Prevent silencing stdout and stderr when a debugger is being used
    unless defined?(Byebug) || defined?(Pry)
      $stderr = File.open(File::NULL, "w")
      $stdout = File.open(File::NULL, "w")
    end

    $config = Config.new("spec/support/test_config.yaml")
    $quiet = true
  end

  config.after(:all) do
    $stderr = original_stderr
    $stdout = original_stdout
  end

  config.before(:each) do
    # Redirect all Redacted requests to the fake Sinatra app
    stub_request(:any, /redacted.ch/).to_rack(FakeRedacted)

    # Stub the wait method so we don't have to abide by our normal API rate
    # limiting mechanism
    allow(Request).to receive(:wait_for_request)
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

Dir[File.dirname(__FILE__) + "/matchers/**/*.rb"].sort.each { |file| require file }
Dir[File.dirname(__FILE__) + "/support/**/*.rb"].sort.each { |file| require file }

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
