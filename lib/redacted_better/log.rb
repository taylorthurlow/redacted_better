class Log
  @@pastel = Pastel.new

  # @see #log
  def self.success(message, newline: true)
    log @@pastel.green(message), newline
  end

  # @see #log
  def self.info(message, newline: true)
    log @@pastel.white(message), newline
  end

  # @see #log
  def self.debug(message, newline: true)
    log @@pastel.blue(message), newline
  end

  # @see #log
  def self.warning(message, newline: true)
    log @@pastel.yellow(message), newline
  end

  # @see #log
  def self.error(message, newline: true)
    log @@pastel.red(message), newline
  end

  # Writes a message to STDOUT. Does nothing if the global `$quiet` flag is
  # set.
  #
  # @param message [String] the message to write
  # @param newline [Boolean] whether or not to add a newline to the message
  def self.log(message, newline)
    return if $quiet

    newline ? puts(message) : print(message)
  end
end
