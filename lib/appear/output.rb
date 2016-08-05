require 'appear/service'
require 'logger'

module Appear
  # The Output service encapsulates writing logging information to log files
  # and STDERR, and writing output to STDOUT.
  class Output
    def initialize(log_file_name, silent)
      @file_logger = Logger.new(log_file_name.to_s) if log_file_name
      @stderr_logger = Logger.new(STDERR) unless silent
    end

    def log(*any)
      @stderr_logger.debug(*any) if @stderr_logger
      @file_logger.debug(*any) if @file_logger
    end

    def log_error(err)
      log("Error #{err.inspect}: #{err.to_s.inspect}")
      if err.backtrace
        err.backtrace.each { |line| log("  " + line) }
      end
    end

    def output(*any)
      STDOUT.puts(*any)
      @file_logger.debug(*any) if @file_logger
    end
  end
end
