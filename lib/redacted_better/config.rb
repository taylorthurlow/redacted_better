class Config
  def self.load_config
    config = TTY::Config.new

    if $opts[:config]
      # User has supplied an alternate config file path
      if File.exist? $opts[:config]
        config.prepend_path File.dirname($opts[:config])
        config.filename = File.basename($opts[:config], ".*")
      else
        Log.error("No configuration file at provided path.")
        exit
      end
    else
      # User wants to use the built in config file path
      config.prepend_path(default_config_path)
      TTY::File.create_dir(default_config_path)
      config.filename = "redacted_better"
      config.extname = ".yaml"

      full_path = File.join(default_config_path, config.filename + config.extname)
      unless File.exist? full_path
        # Copy default config file into place
        config_template = File.join(File.dirname(__FILE__), "..", "default_config.yaml")
        FileUtils.cp(config_template, full_path) do |f|
          "# Default config file, created at #{Time.now}\n\n" + f
        end

        Log.warning("Created an empty configuration file at path:")
        Log.info("  #{full_path}")
        Log.warning("Please edit this file and fill in the appropriate information.")
        exit
      end
    end

    config.read
    config
  end

  private

  def self.default_config_path
    File.join(Dir.home, ".config", "redacted_better")
  end
end
