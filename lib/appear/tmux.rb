require 'appear/service'
require 'appear/util/command_builder'
require 'appear/util/value_class'

module Appear
  # The Tmux service is in charge of interacting with `tmux` processes. It is
  # used by the Tmux revealer, but could also be used as the building block for
  # other tmux-related scripts.
  #
  # see the man page for tmux if you are curious about what clients, windows,
  # panes, and sessions are in Tmux world.
  class Tmux < Service
    delegate :run, :runner

    # A tmux pane.
    class Pane < ::Appear::Util::ValueClass
      # @return [Fixnum] pid of the process running in the pane
      attr_reader :pid

      # @return [String] session name
      attr_reader :session

      # @return [Fixnum] window index
      attr_reader :window

      # @return [Fixnum] pane index
      attr_reader :pane

      # @return [Boolean] is this pane the active pane in this session
      attr_reader :active?, :active

      # @return [String] command running in this pane
      attr_reader :command_name
    end

    # A tmux client.
    class Client < ::Appear::Util::ValueClass
      # @return [String] path to the TTY device of this client
      attr_reader :tty

      # @return [String] term name
      attr_reader :term

      # @return [String] session name
      attr_reader :session
    end

    # List all the tmux clients on the system
    #
    # @return [Array<Client>]
    def clients
      ipc(command('list-clients').flags(:F => format_string(
          :tty => :client_tty,
          :term => :client_termname,
          :session => :client_session
      ))).map { |c| Client.new(c) }
    end

    # List all the tmux panes on the system
    #
    # @return [Array<Pane>]
    def panes
      ipc(command('list-panes').flags(:a => true, :F => format_string(
        :pid => :pane_pid,
        :session => :session_name,
        :window => :window_index,
        :pane => :pane_index,
        :command_name => :pane_current_command,
        :active => :pane_active
      ))).map do |pane|
        Pane.new(pane.merge(
          :window => pane[:window].to_i,
          :pid => pane[:pid].to_i,
          :active => pane[:active].to_i != 0
        ))
      end
    end

    # Reveal a pane in tmux.
    #
    # @param pane [Pane] a pane
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
        info
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
