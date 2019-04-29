class Config
  attr_reader :file_path

  # @param file_path [String, nil] an optional absolute file path to a
  #   configuration file, will use default configuration path if not provided
  def initialize(file_path = nil)
    @tty_config = TTY::Config.new
    @file_path = file_path || default_config_path

    if create_config_file
      Log.warning("Created an empty configuration file at path:")
      Log.info("  #{@file_path}")
      Log.warning("Please edit the configuration and re-run the program.")
      exit
    end

    tty_config_setup
    @tty_config.read
  end

  # Get a configuration option from the TTY::Config instance.
  #
  # @param *keys [Array<Symbol>] the YAML keys to follow which contain the
  #   desired configuration option
  def fetch(*keys)
    @tty_config.fetch(*keys)
  end

  # The default configuration directory.
  def self.config_directory
    File.join(Dir.home, ".config", "redacted_better")
  end

  private

  # The default path to store the configuration file.
  def default_config_path
    File.join(Config.config_directory, "redacted_better.yaml")
  end

  # Set up the TTY::Config instance
  def tty_config_setup
    @tty_config.prepend_path File.dirname(@file_path)
    @tty_config.filename = File.basename(@file_path, ".*")
    @tty_config.extname = File.extname(@file_path)
  end

  # Create the config file using the default config if it does not exist
  # already.
  #
  # @return [Boolean] true if the file was created, false if it was not
  def create_config_file
    if File.exist? @file_path
      false
    else
      FileUtils.mkdir_p(File.dirname(@file_path))
      FileUtils.cp(template_path, @file_path)
      true
    end
  end

  # The file path to a template config which serves as a starting point for a
  # new configuration. This config has a lot of empty configuration options and
  # will not actually work without manual editing.
  def template_path
    File.join(File.dirname(__FILE__), "..", "default_config.yaml")
  end
end
