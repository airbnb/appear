require 'appear/service'
require 'logger'

module Appear
  # The Output service encapsulates writing logging information to log files
  # and STDERR, and writing output to STDOUT.
  class Output
    # Create a new Output service.
    #
    # @param log_file_name [String, nil] if a string, log to the file at this path
    # @param silent [Boolean] if true, output to STDERR
    def initialize(log_file_name, silent)
      @file_logger = Logger.new(log_file_name.to_s) if log_file_name
      @stderr_logger = Logger.new(STDERR) unless silent
    end

    # Log a message.
    #
    # @param any [Array<Any>]
    def log(*any)
      @stderr_logger.debug(*any) if @stderr_logger
      @file_logger.debug(*any) if @file_logger
    end

    # Log an error
    #
    # @param err [Error]
    def log_error(err)
      log("Error #{err.inspect}: #{err.to_s.inspect}")
      if err.backtrace
        err.backtrace.each { |line| log("  " + line) }
      end
    end

    # Output a message to STDOUT, and also to the log file.
    #
    # @param any [Array<Any>]
    def output(*any)
      STDOUT.puts(*any)
      @file_logger.debug(*any) if @file_logger
    end
  end
end
