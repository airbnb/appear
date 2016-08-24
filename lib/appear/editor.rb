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

      require_service :processes
      require_service :tmux
      require_service :runner # needed for sub-services

      # @return [Appear::Editor::Nvim, nil] an nvim editor session suitable for
      #   opeing files, or nil if nvim isn't running or there are no suitable sessions.
      def find_nvim(filename)
        res = ::Appear::Editor::Nvim.find_for_file(filename, services)
        log("nvim for file #{filename.inspect}: #{res.inspect}")
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
        # remember that this can be nil
        nvim = find_nvim(filename)
        pane = nil
        if nvim
          pane = find_tmux_pane(nvim)
        else
          # TODO: implement create_new_session
          nvim, pane = create_ide(filename)
        end

        if nvim.find_buffer(filename)
          nvim.focus_file(filename)
        end

        w, h = nvim.size
        if w > 100
          nvim.open_vsplit(filename)
        else
          nvim.open_tab(filename)
        end

        return nvim, pane
      end

      # Create a new IDE instance editing `filename`
      #
      # @param filename [String]
      def create_ide(filename)
        dir = project_root(filename)
        tmux_session = services.tmux.sessions.sort_by { |s| s.windows.length }.last
        if tmux_session
          window = tmux_session.windows.find do |win|
            panes = win.panes
            panes.length == 1 && panes.first.current_path == dir
          end || tmux_session.new_window(
            # -c: current directory
            :c => dir,
            # -d: do not focus
            :d => true,
          )
        else
          tmux_session = services.tmux.new_session(
            # -c: current directory
            :c => dir
          )
          window = tmux_session.windows.first
        end
        bottom_pane = window.panes.first
        top_pane = bottom_pane.split(
          # take 70% of the space
          :p => 70.0,
          # split into top and bottom
          :v => true,
          # new pane goes on top
          :b => true
        )

        # cut this one in half for laffs - i like having two little terms
        bottom_pane.split_pane

        # launch the editor inside the living shell in the top window
        # sends the command and then a newline
        #-l flag is literal, ensuring keys will be sent as a string
        top_pane.send_keys(nvim_edit_command(filename), "\n", :l => true)

        return find_nvim(filename), top_pane
      end

      # reveal a file in an existing or new IDE session
      #
      # @param filename [String]
      def call(filename)
        nvim, pane = find_or_create_ide(filename)

        # focuses the file in the nvim instance
        nvim.edit_file(filename)

        # focuses the pane in the tmux session
        services.tmux.reveal_pane(pane)

        # gotta get a client
        client_pid = tmux_client_for_tree(processes.process_tree(nvim.pid))
        if client
          Appear.appear(client_pid)
        else
          term_gui = Appear::Terminal.get_active_terminal(services) || Appear::Terminal.Iterm2.new(services)
          term_pane = term_gui.create_tmux_client_for_session(pane.session)
          term_gui.reveal_pane(term_pane)
        end
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
  end
end

require 'appear/editor/nvim'
