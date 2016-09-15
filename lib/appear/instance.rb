require 'logger'
require 'appear/constants'
require 'appear/service'

require 'appear/output'
require 'appear/processes'
require 'appear/runner'
require 'appear/lsof'
require 'appear/mac_os'
require 'appear/tmux'
require 'appear/revealers'

module Appear
  # Instance is the main class in Appear. It constructs all the other services
  # and co-ordinates the actual revealing process.
  class Instance < Service
    delegate :process_tree, :processes

    def initialize(config)
      @config = config

      # provide a reference to this revealer instance so that sub-revealers can
      # appear other process trees, if needed. Our Tmux revealer uses this
      # service to appear the tmux client.
      @all_services = { :revealer => self }

      # instantiate all our various services
      @all_services[:output] = Appear::Output.new(@config.log_file, @config.silent)
      @all_services[:runner] = Appear::Runner.new(@all_services)
      @all_services[:runner] = Appear::RunnerRecorder.new(@all_services) if @config.record_runs
      @all_services[:processes] = Appear::Processes.new(@all_services)
      @all_services[:lsof] = Appear::Lsof.new(@all_services)
      @all_services[:mac_os] = Appear::MacOs.new(@all_services)
      @all_services[:tmux] = Appear::Tmux.new(@all_services)
      @all_services[:terminals] = Appear::Terminals.new([
        Appear::Terminal::Iterm2.new(@all_services),
        Appear::Terminal::TerminalApp.new(@all_services),
      ])

      # make sure we can use our processes service, and log stuff.
      super(@all_services)
    end

    # appear the given PID.
    #
    # @param pid [Number] process id
    # @return [Boolean] true if we revealed something, false otherwise.
    def call(pid)
      tree = process_tree(pid)

      statuses = ::Appear::REVEALERS.map do |klass|
        revealer = klass.new(@all_services)
        revealer.call(tree)
      end

      statuses.any? { |status| !status.nil? }
    end
  end
end
