require 'appear/constants'
require 'appear/config'
require 'appear/instance'
require 'optparse'

module Appear
  class InvalidPidError < Error; end

  # Entrypoint and manager for the command-line `appear` tool.
  class Command
    def initialize
      @config = Appear::Config.new
      @config.silent = true
    end

    def option_parser
      @option_parser ||= OptionParser.new do |o|
        o.banner = 'Usage: appear [options] PID - appear PID in your user interface'
        o.on('-l', '--log-file [PATH]', 'log to a file') do |file|
          @config.log_file = file
        end

        o.on('-v', '--verbose', 'tell many tales about how the appear process is going') do |flag|
          @config.silent = false if flag
        end

        o.on('--record-runs', 'record every executed command as a JSON file') do |flag|
          @config.record_runs = flag
        end
      end
    end

    def execute(all_args)
      argv = option_parser.parse!(all_args)

      pid = argv[0].to_i
      if pid == 0
        raise InvalidPidError.new("Invalid PID #{argv[0].inspect} given (parsed to 0).")
      end

      start = Time.now
      revealer = Appear::Instance.new(@config)
      revealer.output("STARTING. pid: #{pid}")
      result = revealer.call(pid)
      finish = Time.now
      revealer.output("DONE. total time: #{finish - start} seconds, success: #{result}")

      if result
        # success! revealed something!
        exit 0
      else
        # did not appear, but no errors encountered
        exit 2
      end
    end
  end
end
