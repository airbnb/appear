require 'ostruct'
require 'appear/service'

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
      ipc([
        'list-clients',
        '-F',
        format_string(
          :tty => :client_tty,
          :term => :client_termname,
          :session => :client_session
      ),
      ])
    end

    # List all the tmux panes on the system
    #
    # @return [Array<OpenStruct>]
    def panes
      panes = ipc([
        'list-panes',
        '-a',
        '-F',
        format_string(
          :pid => :pane_pid,
          :session => :session_name,
          :window => :window_index,
          :pane => :pane_index,
          :command_name => :pane_current_command,
          :active => :pane_active)
      ])

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
      ipc(['select-pane', '-t', "#{pane.session}:#{pane.window}.#{pane.pane}"])
      ipc(['select-window', '-t', "#{pane.session}:#{pane.window}"])
    end

    private

    def ipc(args)
      res = run(['tmux'] + args)
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
