#!/usr/bin/ruby
require 'logger'
require 'pathname'
require 'open3'

logger = Logger.new('/tmp/tmux-ide-app.log')
logger.info('started up!')

begin
  logger.info('started main')
  here = Pathname.new(__FILE__).dirname.realpath
  lib = here.join('appear-gem/lib')
  $:.unshift(lib.to_s)
  logger.info("using library in #{lib}")

  args = [
    '--edit',
    'TmuxIde',
    '--verbose',
    '--log-file',
    '/tmp/tmux-ide-script.log',
    ARGV
  ].flatten
  logger.info("computed argv: #{args}")

  require 'appear/command'
  cmd = ::Appear::Command.new
  logger.info("cmd #{cmd}")
  cmd.execute(args)
  logger.info('done')
rescue Exception => err
  logger.fatal("dying because of error")
  logger.fatal(err)
  exit 1
end
