#!/usr/bin/ruby
require 'logger'
require 'pathname'
require 'open3'

logger = Logger.new('/tmp/tmux-ide-app.log')
logger.info('started up!')

class AppearMacApp
  def initialize(logger)
    @logger = logger
  end

  attr_reader :logger

  def here
    @here ||= Pathname.new(__FILE__).dirname.realpath
  end

  def load_library
    lib = here.join('appear-gem/lib')
    $:.unshift(lib.to_s)
    logger.info("using library in #{lib}")
    require 'appear'
  end


  def main
    logger.info('started main')
    load_library

    if ARGV.empty?
      display_dialog(<<-EOS)
Drop files on this app to open them in Nvim + Tmux.
Make sure to export NVIM_LISTEN_ADDRESS="$HOME/.vim/sockets/vim-zsh-$$.sock"
EOS
      exit 2
    end

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
  end

  def display_dialog(text)
    app_icon = here.join('appIcon.icns').to_s.gsub('/', ':')
    osascript = ::Appear::Util::CommandBuilder.new('osascript')
    osascript.flags(:e => <<-EOS)
    tell app "System Events"
      display dialog #{text.inspect} buttons {"Ok"} default button 1 with title "TmuxIde" with icon file #{app_icon.inspect}
    end tell
    EOS
    out, status = Open3.capture2e(*osascript.to_a)
    logger.info("dialog result: #{out.strip}")
  end
end

begin
  app = AppearMacApp.new(logger)
  app.main
rescue Exception => err
  logger.fatal("dying because of error")
  logger.fatal(err)
  exit 1
end
