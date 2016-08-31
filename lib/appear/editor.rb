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

      def initialize(svcs = {})
        super(svcs)
        @tmux_memo = ::Appear::Util::Memoizer.new
      end

      def update_nvims
        @nvims ||= {}
        @nvim_to_cwd ||= {}
        @cwd_to_nvim ||= {}
        new_nvims = false

        Nvim.sockets.each do |sock|
          next if @nvims[sock]

          new_nvims = true
          nvim = Nvim.new(sock, services)
          @nvims[sock] = nvim
          cwd = nvim.cwd
          @nvim_to_cwd[nvim] = cwd
          @cwd_to_nvim[cwd] = nvim
        end

        if new_nvims
          @cwd_by_depth = @cwd_to_nvim.keys.sort_by { |d| Pathname.new(d).each_filename.to_a.length }
        end
      end

      # as dumb as they come
      def path_contains?(parent, child)
        p, c = Pathname.new(parent), Pathname.new(child)
        c.expand_path.to_s.start_with?(p.expand_path.to_s)
      end

      # Find the appropriate Nvim session for a given filename. First, we try
      # to find a session actually editing this file. If none exists, we find
      # the session with the deepest CWD that contains the filename.
      #
      # @param filename [String]
      # @return [::Appear::Editor::Nvim, nil]
      def find_nvim_for_file(filename)
        update_nvims
        cwd_to_nvim = {}

        @nvims.each do |_, nvim|
          return nvim if nvim.find_buffer(filename)
        end

        match = @cwd_by_depth.find { |cwd| path_contains?(cwd, filename) }
        return nil unless match
        @cwd_to_nvim[match]
      end

      # find the tmux pane holding an nvim editor instance.
      #
      # @param nvim [Appear::Editor::Nvim]
      # @return [Appear::Tmux::Pane, nil] the pane, or nil if not found
      def find_tmux_pane(nvim)
        @tmux_memo.call(nvim) do
          tree = services.processes.process_tree(nvim.pid)
          tmux_server = tree.find { |p| p.name == 'tmux' }
          next nil unless tmux_server

          # the first join should be the tmux pane holding our
          # nvim session.
          proc_and_panes = Util::Join.join(:pid, services.tmux.panes, tree)
          pane_join = proc_and_panes.first
          next nil unless pane_join

          # new method on join: let's you get an underlying
          # object out of the join if it matches a predicate.
          next pane_join.unjoin do |o|
            o.is_a? ::Appear::Tmux::Pane
          end
        end
      end

      # Find or create an IDE, then open this file in it.
      #
      # @param filename [String]
      def find_or_create_ide(filename)
        nvim = find_nvim_for_file(filename)
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
        #[left, right].each_with_index do |pane, idx|
          #pane.send_keys(["bottom pane ##{idx}"], :l => true)
        #end

        # Hacky way to wait for nvim to launch! This should take at most 2
        # seconds, otherwise your vim is launching too slowley ;)
        wait_until(2) { (services.processes.pgrep(Nvim::NEOVIM) - existing_nvims).length >= 1 }

        nvim = find_nvim_for_file(filename)
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
      def call(*filenames)
        nvims = []
        nvim_to_session = {}

        filenames.each do |filename|
          filename = File.expand_path(filename)
          nvim, pane = find_or_create_ide(filename)
          # focuses the file in the nvim instance, or start editing it.
          Thread.new { nvim.drop(filename) }
          nvims << nvim unless nvims.include?(nvim)
          nvim_to_session[nvim] = pane.session
        end

        nvims.map do |nvim|
          Thread.new do
            # go ahead and reveal our nvim
            next true if services.revealer.call(nvim.pid)

            session = nvim_to_session[nvim]
            # if we didn't return, we need to create a Tmux client for our
            # session.
            command = services.tmux.attach_session_command(session)
            terminal = services.terminals.get
            term_pane = terminal.new_window(command.to_s)
            terminal.reveal_pane(term_pane)
          end
        end.each(&:join)

        log "#{self.class}: finito."
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
