module Appear
  # all the adjustable options for a Appear::Instance
  class Config
    # if set, the Appear::Instance will log debug information to this file.
    # @type String, nil
    attr_accessor :log_file

    # if false, the Appear::Instance will log debug information to STDERR.
    # @type Boolean
    attr_accessor :silent

    # Record everything executed by Runner service to spec/command_output.
    # Intended for generating test cases.
    attr_accessor :record_runs

    # sets defaults
    def initialize
      self.silent = true
      self.record_runs = false
    end
  end
end
