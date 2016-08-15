require 'ostruct'
require 'appear/service'
require 'appear/util/command_builder'

module Appear
  # The Tmux service is in charge of interacting with `tmux` processes. It is
  # used by the Tmux revealer, but could also be used as the building block for
  # other tmux-related scripts.
  #
  # see the man page for tmux if you are curious about what clients, windows,
  # panes, and sessions are in Tmux world.
  class Tmux < Service
    delegate :run, :runner

    # List all the tmux clients on the system
    #
    # @return [Array<OpenStruct>]
    def clients
      ipc(command('list-clients').flags(:F => format_string(
          :tty => :client_tty,
          :term => :client_termname,
          :session => :client_session
      )))
    end

    # List all the tmux panes on the system
    #
    # @return [Array<OpenStruct>]
    def panes
      panes = ipc(command('list-panes').flags(:a => true, :F => format_string(
        :pid => :pane_pid,
        :session => :session_name,
        :window => :window_index,
        :pane => :pane_index,
        :command_name => :pane_current_command,
        :active => :pane_active
      )))

      panes.each do |pane|
        pane.window = pane.window.to_i
        pane.pid = pane.pid.to_i
        pane.active = pane.active.to_i != 0
      end

      panes
    end

    # Reveal a pane in tmux.
    #
    # @param pane [OpenStruct] a pane returned from {#panes}
    def reveal_pane(pane)
      ipc(command('select-pane').flags(:t => "#{pane.session}:#{pane.window}.#{pane.pane}"))
      ipc(command('select-window').flags(:t => "#{pane.session}:#{pane.window}"))
    end

    private

    def command(subcommand)
      Appear::Util::CommandBuilder.new(['tmux', subcommand])
    end

    def ipc(cmd)
      res = run(cmd.to_a)
      res.lines.map do |line|
        info = {}
        line.strip.split(' ').each do |pair|
          key, *value = pair.split(':')
          info[key.to_sym] = value.join(':')
        end
        OpenStruct.new(info)
      end
    end

    def format_string(spec)
      result = ""
      spec.each do |key, value|
        part = ' ' + key.to_s + ':#{' + value.to_s + '}'
        result += part
      end
      result
    end
  end
end
