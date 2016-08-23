require 'appear/service'
require 'appear/util/join'
require 'ostruct'

module Appear
  # stores all the ways we can appear something
  REVEALERS = []

  # The Revealers are the things that actually are in charge of revealing a PID
  # in a terminal emulator. They consume the other services to do the real
  # work.
  module Revealers
    # extend to implement more revealers
    class BaseRevealer < Service
      # Reveal `tree` if supported by this revealer. You can get a tree from
      # {Processes#process_tree}.
      #
      # @param tree [Array<Processes::ProcessInfo>]
      # @return [true, nil] return true if we revealed something, otherwise nil
      def call(tree)
        target, *rest = tree
        if supports_tree?(target, rest)
          return reveal_tree(tree)
        end
      end

      # Reveal `tree`. Should be implemented by subclasses.
      #
      # @abstract subclasses must implement this method.
      # @param tree [Array<Processes::ProcessInfo>]
      # @return [true, nil] return true if we revealed something, otherwise nil
      def reveal_tree(tree)
        raise "not implemented"
      end

      # Returns true if this revealer may be able to reveal something in the
      # tree. For this method, the caller splits the tree into the target and
      # the rest of the tree, which sometimes simplifies the implementation of
      # this method.
      #
      # @abstract subclasses must implement this method.
      # @param target [Processes::ProcessInfo] bottom (child-most) item in the process
      #   tree
      # @param rest [Array<Processes::ProcessInfo>] the rest of the tree
      # @return [Boolean]
      def supports_tree?(target, rest)
        raise "not implemented"
      end

      # Register this class as a revealer so it will be called by
      # {Instance#call}
      def self.register!
        Appear::REVEALERS.push(self)
      end
    end

    # Base class for Mac-terminal revealers.
    class MacRevealer < BaseRevealer
      delegate :join_via_tty, :lsof
      require_service :mac_os

      # Enumerate the panes (seperate interactive sessions) that this terminal
      # program has.
      #
      # @abstract subclasses must implement this method.
      # @return [Array<#tty>] any objects with a tty field
      def panes
        raise "not implemented"
      end

      # Reveal a hit. Subclasses must implement this method.
      #
      # @abstract subclasses must implement this method.
      # @param hit [#tty] any object with a tty field
      def reveal_hit(hit)
        raise "not implemented"
      end

      # Implementation.
      # @see BaseRevealer#reveal_tree
      def reveal_tree(tree)
        hits = join_via_tty(tree, panes)
        actual_hits = hits.uniq {|hit| hit.tty }.
          reject {|hit| services.mac_os.has_gui?(hit.process) }.
          each { |hit| reveal_hit(hit) }

        return actual_hits.length > 0
      end

      # True if the tree has a GUI app with the given name.
      # Helps when implementing the {#supports_tree?} method.
      #
      # @param tree [Array<Processes::ProcessInfo>]
      # @param name [String]
      # @return [Boolean]
      # @todo: read the bundle identifier somehow, but this is close enough.
      #   or get the bundle identifier and enhance the process lists with it?
      def has_gui_app_named?(tree, name)
        tree.any? do |process|
          process.name == name && services.mac_os.has_gui?(process)
        end
      end
    end

    # support for iTerm2
    class Iterm2 < MacRevealer
      require_service :processes

      def supports_tree?(target, rest)
        has_gui_app_named?(rest, 'iTerm2')
      end

      # @see MacRevealer#panes
      def panes
        pids = services.processes.pgrep('iTerm2')
        services.mac_os.call_method('iterm2_panes').map do |hash|
          hash[:pids] = pids
          OpenStruct.new(hash)
        end
      end

      # @see MacRevealer#reveal_hit
      def reveal_hit(hit)
        services.mac_os.call_method('iterm2_reveal_tty', hit.tty)
      end
    end

    # support for Apple's built-in Terminal.app
    class TerminalApp < MacRevealer
      require_service :processes

      # Implementation.
      # @see BaseRevealer#supports_tree?
      def supports_tree?(target, rest)
        has_gui_app_named?(rest, 'Terminal')
      end

      # @see MacRevealer#panes
      def panes
        pids = services.processes.pgrep('Terminal.app')
        services.mac_os.call_method('terminal_panes').map do |hash|
          hash[:pids] = pids
          OpenStruct.new(hash)
        end
      end

      # @see MacRevealer#reveal_hit
      def reveal_hit(hit)
        # iterm2 runs a non-gui server process. Because of implementation
        # details of MacOs#has_gui?, we don't *techinically* have to worry
        # about this, but we should in case I ever implement real mac
        # gui-or-not lookup.
        return if hit.process.name == 'iTerm2'
        services.mac_os.call_method('terminal_reveal_tty', hit.tty)
      end
    end

    # support for the cross-platform Tmux multiplexer. Also reveals a connected
    # tmux client, if possible.
    class Tmux < BaseRevealer
      # TODO: cache services.tmux.panes, services.tmux.clients for this revealer?
      require_service :tmux
      require_service :lsof
      require_service :revealer
      require_service :processes

      # Implementation.
      # @see BaseRevealer#supports_tree?
      def supports_tree?(target, rest)
        rest.any? { |p| p.name == 'tmux' }
      end

      # Implementation.
      # @see BaseRevealer#reveal_tree
      def reveal_tree(tree)
        relevent_panes = Util::Join.join(:pid, tree, services.tmux.panes)
        relevent_panes.each do |pane|
          log("#{self.class.name}: revealing pane #{pane}")
          services.tmux.reveal_pane(pane)
        end

        # we should also appear the tmux client for this tree in the gui
        pid = tmux_client_for_tree(tree)
        if pid
          services.revealer.call(pid)
        end

        return relevent_panes.length > 0
      end

      # tmux does not tell us the PIDs of any of these clients. The only way
      # to find the PID of a tmux client is to lsof() the TTY that the client
      # is connected to, and then deduce the client PID, which will be a tmux
      # process PID that is not the server PID.
      #
      # @param tree [Array<Processes::ProcessInfo>]
      # @return [Number, nil] pid of a tmux client, if one was found. Otherwise
      #   nil.
      def tmux_client_for_tree(tree)
        tmux_server = tree.find {|p| p.name == 'tmux'}

        # join processes on tmux panes by PID.
        proc_and_panes = Util::Join.join(:pid, services.tmux.panes, tree)

        # Join the list of tmux clients with process_and_pid on :session.
        # In tmux, every pane is addressed by session_name:window_index:pane_index.
        # This gives us back a list of all the clients that have a pane that
        # contains a process in our given process tree.
        proc_and_clients = Util::Join.join(:session, services.tmux.clients, proc_and_panes)

        # there *should* be only one of these, unless there are two clients
        # connected to the same tmux session. In that case we just choose one
        # of the clients.
        client = proc_and_clients.last

        # at this point it's possible that none of our tree's processes are
        # alive inside tmux.
        return nil unless client

        tty_of_client = client[:tty]
        connections_to_tty = services.lsof.lsofs(
          [tty_of_client],
          :pids => services.processes.pgrep('tmux')
        )[tty_of_client]

        client_connection = connections_to_tty.find do |conn|
          (conn.command_name =~ /^tmux/) && (conn.pid != tmux_server.pid)
        end

        if client_connection
          log("tmux_client_for_tree: found client pid=#{client_connection.pid} for tree pid=#{tree.first.pid}")
          return client_connection.pid
        end
      end
    end

    Iterm2.register!
    TerminalApp.register!
    Tmux.register!
  end
end
