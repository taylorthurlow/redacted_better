require 'pry-byebug'

require 'faraday'
require 'pastel'
require 'require_all'
require 'slop'
require 'tty-config'
require 'tty-file'
require 'tty-prompt'

require_rel 'redacted_better'

class RedactedBetter
  def initialize
    @opts = Slop.parse do |o|
      o.string '-c', '--config', 'path to an alternate config file'
      o.string '-u', '--username', 'your redacted username'
      o.string '-p', '--password', 'your redacted password'
      o.bool '-h', '--help', 'print help'
      o.on '--version', 'print the version' do
        puts RedactedBetter::VERSION
        exit
      end
    end

    handle_help_opt

    @config = load_config
    @username = find_username
    @password = find_password
  end

  def self.root
    File.expand_path('..', __dir__)
  end

  private

  def find_username
    @opts[:username] ||
      @config.fetch(:username) ||
      TTY::Prompt.new.ask('Redacted username?', required: true, modify: :strip)
  end

  def find_password
    @opts[:password] ||
      @config.fetch(:password) ||
      TTY::Prompt.new.ask('Redacted password?', required: true)
  end

  def handle_help_opt
    if @opts[:help]
      puts @opts
      exit
    end
  end

  def load_config
    config = TTY::Config.new

    if @opts[:config]
      # User has supplied an alternate config file path
      if File.exist? @opts[:config]
        config.prepend_path File.dirname(@opts[:config])
        config.filename = File.basename(@opts[:config], '.*')
      else
        puts Pastel.new.red('No configuration file at provided path.')
        exit
      end
    else
      # User wants to use the built in config file path
      default_path = File.join(Dir.home, '.config', 'redacted_better')
      config.prepend_path default_path
      TTY::File.create_dir(default_path)
      config.filename = 'redacted_better'
      config.extname = '.yaml'

      full_path = File.join(default_path, config.filename + config.extname)
      unless File.exist? full_path
        # Copy default config file into place
        TTY::File.copy_file('default_config.yaml', full_path) do |f|
          "# Default config file, created at #{Time.now}\n\n" + f
        end
      end
    end

    config.read
    config
  end
end
