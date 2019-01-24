class Log
  @@pastel = Pastel.new

  def self.success(message, newline: true)
    log @@pastel.green(message), newline
  end

  def self.info(message, newline: true)
    log @@pastel.white(message), newline
  end

  def self.warning(message, newline: true)
    log @@pastel.yellow(message), newline
  end

  def self.error(message, newline: true)
    log @@pastel.red(message), newline
  end

  def self.log(message, newline)
    return if $quiet

    newline ? puts(message) : print(message)
  end
end
