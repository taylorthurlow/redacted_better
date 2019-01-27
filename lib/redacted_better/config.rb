class Config
  def self.load_config
    config = TTY::Config.new

    if $opts[:config]
      # User has supplied an alternate config file path
      if File.exist? $opts[:config]
        config.prepend_path File.dirname($opts[:config])
        config.filename = File.basename($opts[:config], '.*')
      else
        Log.error('No configuration file at provided path.')
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
