module Appear
  # all the adjustable options for a Appear::Instance
  class Config
    # if set, the Appear::Instance will log debug information to this file.
    # @return [String, nil] default nil
    attr_accessor :log_file

    # if false, the Appear::Instance will log debug information to STDERR.
    # @return [Boolean] default true
    attr_accessor :silent

    # Record everything executed by Runner service to spec/command_output.
    # Intended for generating test cases.
    #
    # @return [Boolean] default false
    attr_accessor :record_runs

    # @return [Boolean] default false
    attr_accessor :edit_file

    # @return [String, nil] default nil
    attr_accessor :editor

    # sets defaults
    def initialize
      self.silent = true
      self.record_runs = false
      self.edit_file = false
    end
  end
end
