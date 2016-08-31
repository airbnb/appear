# Appear your terminal programs in your gui!
#
# Appear is a tool for revealing a given process in your terminal. Given a
# process ID, `appear` finds the terminal emulator view (be it a window, tab,
# or pane) containing that process and shows it to you. Appear understands
# terminal multiplexers like `tmux`, so if your target process is in a
# multiplexer session, `appear` will reveal a client connected to that session,
# or start one if needed.
#
# Most users of this library will find the {Appear.appear} method sufficient,
# although you may construct and control library internals using the
# {Appear::Instance} class, which is our "main" class.
#
# Other useful ideas include the {Appear::BaseService} class, which is a
# super-simple dependency-injection base class.
#
# @author Jake Teton-Landis <just.1.jake@gmail.com>
module Appear
  # Appear the given PID in your user interfaces.
  # This method is an easy public interface to Appear for ruby consumers.
  # @param pid [Number] pid to Appear.
  # @param config [Appear::Config, nil] a config for adjusting verbosity and logging.
  def self.appear(pid, config = nil)
    config ||= Appear::Config.new
    instance = Appear::Instance.new(config)
    instance.call(pid)
  end

  # Build a command string that will execute `appear` with the given config and
  # arguments. If `appear` is in your PATH, we will use that binary. Otherwise,
  # we will call the script in ./bin/ folder near this library, which has a
  # #!/usr/bin/env ruby shbang.
  #
  # You may optionally need to prepend "PATH=#{ENV['PATH']} " to the command if
  # `tmux` is not in your command execution environment's PATH.
  #
  # Intended for use with the terminal-notifier gem.
  # @see https://github.com/julienXX/terminal-notifier/tree/master/Ruby
  #
  # @example Show a notification that will raise your program
  #   require 'appear'
  #   require 'terminal-notifier'
  #   TerminalNotifier.notify('Click to appear!', :execute => Appear.build_command(Process.pid))
  #
  # @param pid [Number] pid to Appear.
  # @param config [Appear::Config, nil] a config for adjusting verbosity and logging.
  # @return [String] a shell command that will execute `appear`
  def self.build_command(pid, config = nil)
    binary = `which appear`.strip
    if binary.empty?
      binary = Appear::MODULE_DIR.join('bin/appear').to_s
    end

    command = Appear::Util::CommandBuilder.new(binary).args(pid)

    if config
      command.flag('verbose', true) unless config.silent
      command.flag('log-file', config.log_file) if config.log_file
      command.flag('record-runs', true) if config.record_runs
    end

    command.to_s
  end
end

require 'appear/config'
require 'appear/instance'
require 'appear/util/command_builder'
