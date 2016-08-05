module Appear
  # This method is an easy public interface to Appear for ruby consumers.
  # Appear the given PID in your user interfaces.
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
