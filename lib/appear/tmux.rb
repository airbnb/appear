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
  #
  # @todo move value object parsing and format string into value class definition
  # @todo all create-foo methods should return a value class of the thing
  #   created, so we don't have to re-select it.
  # @todo refactor into smaller files?
  class Tmux < Service
    delegate :run, :runner

    class TmuxValue < ::Appear::Util::ValueClass
      # @return [Tmux] the tmux service that created this pane
      attr_reader :tmux

      def self.attr_map(map)
        @tmux_attr_map = map
      end

      def self.format_string
        hsh = {}
        @tmux_attr_map.each do |k, v|
          if v.is_a? Array
            hsh[h] = v.first
          else
            hsh[h] = v
          end
        end
        hsh
      end
    end

    # A tmux pane.
    class Pane < TmuxValue
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

      # @return [String] pane current path
      attr_reader :current_path

      # String suitable for use as the "target" specifier for a Tmux command
      #
      # @return [String]
      def target
        "#{session}:#{window}.#{pane}"
      end

      def split(opts = {})
        tmux.split_window(opts.merge(:t => target))
      end
    end

    # A tmux session.
    # Has many windows.
    class Session < TmuxValue
      # @return [String] session name
      attr_reader :session

      def target
        session
      end

      def windows
        tmux.windows.select { |w| w.session == session }
      end

      def clients
        tmux.clients.select { |c| c.session == session }
      end

      def new_window(opts = {})
        win = windows.last.window || -1
        tmux.new_window(opts.merge(:t => "#{target}:#{win + 1}"))
      end
    end

    # A tmux window.
    # Has many panes.
    class Window < TmuxValue
      # @return [String] session name
      attr_reader :session

      # @return [Fixnum] window index
      attr_reader :window

      # @return [String] window id
      attr_reader :id

      # @return [Boolean] is the window active?
      attr_reader :active?, :active

      def panes
        tmux.panes.select { |p| p.session == session && p.window == window }
      end

      def target
        "#{session}:#{window}"
      end
    end

    # A tmux client.
    class Client < TmuxValue
      # @return [String] path to the TTY device of this client
      attr_reader :tty

      # @return [String] term name
      attr_reader :term

      # @return [String] session name
      attr_reader :session

      # @return [Tmux] the tmux service that created this pane
      attr_reader :tmux
    end

    # List all the tmux clients on the system
    #
    # @return [Array<Client>]
    def clients
      ipc(command('list-clients').flags(:F => format_string(
          :tty => :client_tty,
          :term => :client_termname,
          :session => :client_session
      ))).map { |c| Client.new(c.merge(:tmux => self)) }
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
        :current_path => :pane_current_path,
        :active => :pane_active
      ))).map do |pane|
        Pane.new(pane.merge(
          :window => pane[:window].to_i,
          :pane => pane[:pane].to_i,
          :pid => pane[:pid].to_i,
          :active => pane[:active].to_i != 0,
          :tmux => self
        ))
      end
    end

    # List all the tmux sessions on the system
    #
    # @return [Array<Session>]
    def sessions
      ipc(command('list-sessions').flags(:F => format_string(
        :session => :session_name,
        :id => :session_id,
        :attached => :session_attached,
        :width => :session_width,
        :height => :session_height,
      ))).map do |s|
        Session.new(s.merge(
          :tmux => self,
          :attached => s[:attached].to_i,
          :width => s[:width].to_i,
          :height => s[:height].to_i,
        ))
      end
    end

    # List all the tmux windows in any session on the system
    #
    # @return [Array<Window>]
    def windows
      ipc(command('list-windows').flags(:a => true, :F => format_string(
        :session => :session_name,
        :window => :window_index,
        :id => :window_id,
        :active => :window_active,
      ))).map do |w|
        Window.new(w.merge(
          :tmux => self,
          :window => w[:window].to_i,
          :active => w[:window].to_i != 0,
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

    def new_window(opts = {})
      run(command('new-window').flags(opts).to_a)
    end

    def split_window(opts = {})
      run(command('split-window').flags(opts).to_a)
    end

    def new_session(opts = {})
      s = ipc(command('new-session').flags(opts.merge(:F => format_string(
        :session => :session_name,
        :id => :session_id,
        :attached => :session_attached,
        :width => :session_width,
        :height => :session_height,
      )))).first

      Session.new(s.merge(
        :tmux => self,
        :attached => s[:attached].to_i,
        :width => s[:width].to_i,
        :height => s[:height].to_i,
      ))
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
