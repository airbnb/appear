require 'pathname'

module Appear
  # the version of Appear
  VERSION = '1.2.1'

  # root error for our library; all other errors inherit from this one.
  class Error < StandardError; end

  # the root of the Appear project directory
  MODULE_DIR = Pathname.new(__FILE__).realpath.join('../../..')

  # where we look for os-specific helper files
  TOOLS_DIR = MODULE_DIR.join('tools')
end
