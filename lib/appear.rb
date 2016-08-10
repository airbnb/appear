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
end

require 'appear/config'
require 'appear/instance'
