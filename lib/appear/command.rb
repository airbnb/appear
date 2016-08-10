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
        o.banner =  'Usage: appear [OPTION]... [PID]'
        o.separator 'Appear PID in your user interface.'
        o.separator 'Appear will use the current process PID by default.'
        o.separator ''
        o.separator 'Options:'

        o.on('-l', '--log-file [PATH]', 'log to a file') do |file|
          @config.log_file = file
        end

        o.on('-v', '--verbose', 'tell many tales about how the appear process is going') do |flag|
          @config.silent = false if flag
        end

        o.on('--record-runs', 'record every executed command as a JSON file in the appear spec folder') do |flag|
          @config.record_runs = flag
        end

        o.on('--version', 'show version information, then exit') do
          puts "appear #{Appear::VERSION}"
          puts "  author: Jake Teton-Landis"
          puts "  repo: https://github.com/airbnb/appear"
          exit 2
        end

        o.on('-?', '-h', '--help', 'show this help, then exit') do
          puts o
          exit 2
        end

        o.separator ''
        o.separator 'Exit status:'
        o.separator '  0  if successfully revealed something,'
        o.separator '  1  if an exception occured,'
        o.separator '  2  if there were no errors, but nothing was revealed.'
      end
    end

    # @param all_args [Array<String>] something like ARGV
    def execute(all_args)
      argv = option_parser.parse(*all_args)

      pid = Integer(argv[0] || Process.pid, 10)

      start_message = "STARTING. pid: #{pid}"
      if argv.empty?
        start_message += " (current process pid)"
      end

      start = Time.now
      revealer = Appear::Instance.new(@config)
      revealer.log(start_message)
      result = revealer.call(pid)
      finish = Time.now
      revealer.log("DONE. total time: #{finish - start} seconds, success: #{result}")

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
