require 'appear/util/command_builder'
require 'appear/util/join'

module Appear
  # Appear::Editor is a sub-library of Appear, for appearing files, instead of
  # processes. Appear::Editor's job is to open a given file in an existing
  # editor session, or start a new session editing that file.
  #
  # Appear::Editor should feature drivers for many editors in the future, but
  # for now only drives Neovim via [neovim-remote][nvr]. We should also support
  # treating `tmux` as an editor, and launching tmux sessions and creating
  # windows and splits as such.
  #
  # @example define my editor
  #
  # [nvr]: https://github.com/mhinz/neovim-remote
  module Editor
    # TmuxIde is an editor that treasts a collection of Tmux splits holding an
    # Nvim process as an IDE. A "session" is a Tmux window that at least
    # contains an Nvim instance, although new sessions are split like this:
    # -------------
    # |           |
    # |   nvim    |
    # |           |
    # |-----------|
    # |$    |$    |
    # |     |     |
    # |-----------|
    class TmuxIde < Service

      require_service :revealer
      require_service :processes
      require_service :tmux
      require_service :runner # needed for sub-services
      require_service :lsof # needed for sub-services
      require_service :terminals

      # @return [Appear::Editor::Nvim, nil] an nvim editor session suitable for
      #   opeing files, or nil if nvim isn't running or there are no suitable sessions.
      def find_nvim(filename)
        res = ::Appear::Editor::Nvim.find_for_file(filename, services)
        log("nvim for file #{filename.inspect}: #{res}")
        res
      end

      # find the tmux pane holding an nvim editor instance.
      #
      # @param nvim [Appear::Editor::Nvim]
      # @return [Appear::Tmux::Pane, nil] the pane, or nil if not found
      def find_tmux_pane(nvim)
        tree = services.processes.process_tree(nvim.pid)
        tmux_server = tree.find { |p| p.name == 'tmux' }
        return nil unless tmux_server

        # the first join should be the tmux pane holding our
        # nvim session.
        proc_and_panes = Util::Join.join(:pid, services.tmux.panes, tree)
        pane_join = proc_and_panes.first
        return nil unless pane_join

        # new method on join: let's you get an underlying
        # object out of the join if it matches a predicate.
        return pane_join.unjoin do |o|
          o.is_a? ::Appear::Tmux::Pane
        end
      end

      # Find or create an IDE, then open this file in it.
      #
      # @param filename [String]
      def find_or_create_ide(filename)
        nvim = find_nvim(filename)
        return nvim, find_tmux_pane(nvim) unless nvim.nil?
        create_ide(filename)
      end

      # Create a new IDE instance editing `filename`
      #
      # @param filename [String]
      def create_ide(filename)
        dir = project_root(filename)

        # find or create session
        tmux_session = services.tmux.sessions.sort_by { |s| s.windows.length }.last
        tmux_session ||= services.tmux.new_session(
          # -c: current directory
          :c => dir
        )

        # find or create window
        window = tmux_session.windows.find do |win|
          win.panes.first.current_path == dir
        end

        window ||= tmux_session.new_window(
          # -c: current directory
          :c => dir,
          # -d: do not focus
          :d => true,
        )

        # remember our pid list
        existing_nvims = services.processes.pgrep(Nvim::NEOVIM)

        # split window across the middle, into a big and little pane
        main = window.panes.first
        main.send_keys([Nvim.edit_command(filename).to_s, "\n"], :l => true)
        left = main.split(:p => 30, :v => true, :c => dir)
        # cut the smaller bottom pane in half
        right = left.split(:p => 50, :h => true, :c => dir)
        # put a vim in the top pane, and select it
        [left, right].each_with_index do |pane, idx|
          pane.send_keys(["bottom pane ##{idx}"], :l => true)
        end

        # Hacky way to wait for nvim to launch! This should take at most 2
        # seconds, otherwise your vim is launching too slowley ;)
        wait_until(2) { (services.processes.pgrep(Nvim::NEOVIM) - existing_nvims).length >= 1 }

        nvim = find_nvim(filename)
        return nvim, find_tmux_pane(nvim)
      end

      def wait_until(max_duration, sleep = 0.1)
        raise ArgumentError.new("no block given") unless block_given?
        start = Time.new
        limit = start + max_duration
        iters = 0
        while Time.new < limit
          if yield
            log("wait_until(max_duration=#{max_duration}, sleep=#{sleep}) slept #{iters} times, took #{Time.new - start}s")
            return true
          end
          iters = iters + 1
          sleep(sleep)
        end
        false
      end

      # reveal a file in an existing or new IDE session
      #
      # @param filename [String]
      def call(filename)
        nvim, pane = find_or_create_ide(filename)

        # focuses the file in the nvim instance, or start editing it.
        nvim.drop(filename)

        # go ahead and reveal our nvim
        return true if services.revealer.call(nvim.pid)

        # if we didn't return, we need to create a Tmux client for our
        # session.
        command = services.tmux.attach_session_command(pane.session)
        terminal = services.terminals.get
        term_pane = terminal.new_window(command.to_s)
        terminal.reveal_pane(term_pane)
      end

      # Guess the project root for a given path by inspecting its parent
      # directories for certain markers like git roots.
      #
      # @param filename [String]
      # @return [String] some path
      def project_root(filename)
        # TODO: a real constant? Some internet-provided list?
        # these are files that indicate the root of a project
        markers = %w(.git .hg Gemfile package.json setup.py README README.md)
        p = Pathname.new(filename).expand_path
        p.ascend do |path|
          is_root = markers.any? do |marker|
            path.join(marker).exist?
          end

          return path if is_root
        end

        # no markers were found
        return p.to_s if p.directory?
        return p.dirname.to_s
      end
    end

    ALL = [TmuxIde]
  end
end

require 'appear/editor/nvim'
