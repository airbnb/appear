require 'appear/service'
require 'appear/constants'

module Appear
  class Terminals
    def initialize(terminals)
      @terminals = terminals
    end

    def get
      current || default
    end

    private

    def current
      @terminals.find { |t| t.running? }
    end

    def default
      # TODO: select terminals based on OS support or should that happen
      # upstream? in the creator of the Terminals instance? No. It should
      # happen here.
      @terminals.find { |t| t.class == TerminalApp }
    end
  end

  module Terminal
    # Base class for mac terminal support
    class MacTerminal < Service
      require_service :mac_os
      require_service :processes

      # @abstract subclasses must implement this method.
      # @return [String] "app name" on OS X. Both the process name of processes
      #   of this app, and the name used by Applescript to send events to this
      #   app.
      def app_name
        raise NotImplemented
      end

      # @return [Boolean] true if the app has a running process, false
      #   otherwise.
      def running?
        services.processes.pgrep(app_name).length > 0
      end

      # Enumerate the panes (seperate interactive sessions) that this terminal
      # program has.
      #
      # @abstract subclasses must implement this method.
      # @return [Array<#tty>] any objects with a tty field
      def panes
        raise NotImplemented
      end

      # Reveal a pane. Subclasses must implement this method.
      #
      # @abstract subclasses must implement this method.
      # @param pane [#tty] any object with a tty field
      def reveal_pane(pane)
        raise NotImplemented
      end
    end # MacTerminal

    # TerminalApp support service.
    class TerminalApp < MacTerminal
      # @see MacTerminal#app_name
      def app_name
        'Terminal'
      end

      # @see MacTerminal#panes
      def panes
        pids = services.processes.pgrep(app_name)
        services.mac_os.call_method('terminal_panes').map do |hash|
          hash[:pids] = pids
          OpenStruct.new(hash)
        end
      end

      # @see MacTerminal#reveal_pane
      def reveal_pane(pane)
        services.mac_os.call_method('terminal_reveal_tty', pane.tty)
      end
    end

    # Iterm2 support service.
    class Iterm2 < MacTerminal
      # @see MacTerminal#app_name
      def app_name
        'iTerm2'
      end

      # @see MacTerminal#panes
      def panes
        pids = services.processes.pgrep(app_name)
        services.mac_os.call_method('iterm2_panes').map do |hash|
          hash[:pids] = pids
          OpenStruct.new(hash)
        end
      end

      # @see MacTerminal#reveal_pane
      def reveal_pane(pane)
        services.mac_os.call_method('iterm2_reveal_tty', pane.tty)
      end

      # Create a new window running the given command.
      #
      # @param command_str [String] command to run
      # @return [#tty] pane
      def new_window(command_str)
        res = services.mac_os.call_method('iterm2_new_window', command_str)
        OpenStruct.new(res)
      end
    end
  end
end
