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

    class TmuxValue < ::Appear::Util::ValueClass
      # @return [Tmux] the tmux service that created this pane
      attr_reader :tmux

      # @opt opts [Symbol] :tmux tmux format string name of this attribute
      # @opt opts [#to_proc] :parse proc taking a String (read from tmux) and a
      #   hash (the total tmux data) and returns the type-coerced version of this
      #   field. A symbol can be used, just like with usual block syntax.
      def self.attr_reader(name, opts = {})
        super(name, opts)
        @tmux_attrs ||= {}
        @tmux_attrs[name] = opts
      end

      def self.format_string
        result = ""
        @tmux_attrs.each do |reader, opts|
          var = opts.fetch(:var, reader).to_s
          part = ' ' + var + ':#{' + opts.fetch(:tmux).to_s + '}'
          result += part
        end
        result
      end

      def self.parse(tmux_hash, tmux)
        result = tmux_hash.dup
        result.each do |attr, tmux_val|
          tmux, parser = @tmux_attrs[attr]
          if parser
            result[attr] = parser.to_proc.call(tmux_val)
          end
        end
        self.new(result.merge(:tmux => tmux))
      end
    end

    # A tmux pane.
    class Pane < TmuxValue
      # @return [Fixnum] pid of the process running in the pane
      attr_reader :pid, tmux: :pane_pid, parse: :to_i

      # @return [String] session name
      attr_reader :session, tmux: :session_name

      # @return [Fixnum] window index
      attr_reader :window, tmux: :window_index, parse: :to_i

      # @return [Fixnum] pane index
      attr_reader :pane, tmux: :pane_index, parse: :to_i

      # @return [Boolean] is this pane the active pane in this session
      attr_reader :active?, var: :active, tmux: :pane_active, parse: proc {|a| a.to_i != 0 }

      # @return [String] command running in this pane
      attr_reader :command_name, tmux: :pane_current_command

      # @return [String] pane current path
      attr_reader :current_path, tmux: :pane_current_path

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
      attr_reader :session, tmux: :session_name

      attr_reader :id, :tmux => :session_id
      attr_reader :attached, :tmux => :session_attached, :parse => :to_i
      attr_reader :width, :tmux => :session_attached, :parse => :to_i
      attr_reader :height

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
      attr_reader :session, :tmux => :session_name

      # @return [Fixnum] window index
      attr_reader :window, :tmux => :window_index, :parse => :to_i

      # @return [String] window id
      attr_reader :id, :tmux => :window_id

      # @return [Boolean] is the window active?
      attr_reader :active?, :tmux => :window_active, :var => :active, :parse => proc {|b| b.to_i != 0}

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
      attr_reader :tty, :tmux => :client_tty

      # @return [String] term name
      attr_reader :term, :tmux => :client_termname

      # @return [String] session name
      attr_reader :session, :tmux => :client_session
    end

    # List all the tmux clients on the system
    #
    # @return [Array<Client>]
    def clients
      ipc_returning(command('list-clients'), Client)
    end

    # List all the tmux panes on the system
    #
    # @return [Array<Pane>]
    def panes
      ipc_returning(command('list-panes').flags(:a => true), Pane)
    end

    # List all the tmux sessions on the system
    #
    # @return [Array<Session>]
    def sessions
      ipc_returning(command('list-sessions'), Session)
    end

    # List all the tmux windows in any session on the system
    #
    # @return [Array<Window>]
    def windows
      ipc(command('list-windows').flags(:a => true), Window)
    end

    # Reveal a pane in tmux.
    #
    # @param pane [Pane] a pane
    def reveal_pane(pane)
      ipc(command('select-pane').flags(:t => "#{pane.session}:#{pane.window}.#{pane.pane}"))
      ipc(command('select-window').flags(:t => "#{pane.session}:#{pane.window}"))
      pane
    end

    def new_window(opts = {})
      ipc_returning(command('new-window').flags(opts), Window)
    end

    def split_window(opts = {})
      ipc_returning(command('split-window').flags(opts), Pane)
    end

    def new_session(opts = {})
      ipc_returning(command('new-session').flags(opts), Session)
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

    def ipc_returning(cmd, klass)
      cmd.flags(:F => klass.format_string)
      ipc(cmd).map do |row|
        klass.parse(row, self)
      end
    end
  end
end
