class Log
  @@pastel = Pastel.new

  def self.success(message)
    puts @@pastel.green(message) unless $quiet
  end

  def self.info(message)
    puts @@pastel.white(message) unless $quiet
  end

  def self.warning(message)
    puts @@pastel.yellow(message) unless $quiet
  end

  def self.error(message)
    puts @@pastel.red(message) unless $quiet
  end
end
