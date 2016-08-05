require 'open3'
require 'appear/constants'
require 'appear/service'
require 'shellwords'
require 'json'

module Appear
  # raised when a command we want to run fails
  class ExecutionFailure < Error
    attr_reader :command, :output
    def initialize(command, output)
      @command = command
      @output = output
      super("Command #{command.inspect} failed with output #{output.inspect}")
    end
  end

  # Service for executing commands. Better than a mixin everywhere.
  class Runner < Service
    # Run a command. Throws an exception if the command fails. Command can
    # either be a string, or an array of command name and parameters.
    # Returns the combinded STDERR and STDOUT of the command.
    #
    # @return String
    def run(command)
      start = Time.new
      if command.is_a? Array
        output, status = Open3.capture2e(*command)
      else
        output, status = Open3.capture2e(command)
      end
      finish = Time.new
      log("Runner: ran #{command.inspect} in #{finish - start}s")
      raise ExecutionFailure.new(command, output) unless status.success?
      output
    end
  end

  # Records every command run to a directory; intended to be useful for later integration tests.
  class RunnerRecorder < Runner
    OUTPUT_DIR = MODULE_DIR.join('spec/command_output')
    INIT_AT = Time.new

    def initialize(*args)
      super(*args)
      @command_runs = Hash.new { |h, k| h[k] = [] }
    end

    def run(command)
      begin
        result = super(command)
        record_success(command, result)
        return result
      rescue ExecutionFailure => err
        record_error(command, err)
        raise err
      end
    end

    private

    def command_name(command)
      if command.is_a?(Array)
        File.basename(command.first)
      else
        File.basename(command.split(/\s+/).first)
      end
    end

    def record_success(command, result)
      data = {
          :command => command,
          :output => result,
          :status => :success,
      }
      record(command, data)
    end

    def record_error(command, err)
      data = {
          :command => command,
          :output => err.output,
          :status => :error,
      }
      record(command, data)
    end

    def record(command, data)
      name = command_name(command)
      run_index = @command_runs[name].length

      data[:run_index] = run_index
      data[:record_at] = Time.new
      data[:init_at] = INIT_AT

      @command_runs[name] << data
      filename = "#{INIT_AT.to_i}-#{name}-run#{run_index}.json"
      OUTPUT_DIR.join(filename).write(JSON.pretty_generate(data))
    end
  end
end
