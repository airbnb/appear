require 'pathname'

module Appear
  VERSION = '1.0.3'

  # root error for our library; all other errors inherit from this one.
  class Error < StandardError; end

  # we also put common constants in here because it's a good spot.
  # Should we rename this file to 'appear/constants' ?

  # the root of the Appear project directory
  MODULE_DIR = Pathname.new(__FILE__).realpath.join('../../..')

  # where we look for os-specific helper files
  TOOLS_DIR = MODULE_DIR.join('tools')
end
