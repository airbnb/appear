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
    class TmuxIde < Appear::Editor
      # @return [Appear::Editor::Nvim, nil] an nvim editor session suitable for
      #   opeing files, or nil if nvim isn't running or there are no suitable sessions.
      def find_nvim
        raise NotImplemented
      end

      def find_tmux_pane(nvim)
        tree = services.processes.process_tree(nvim.pid)
        tmux_server = tree.find { |p| p.name == 'tmux' }
        return nil unless tmux

        # the first join should be the tmux pane holding our
        # nvim session.
        proc_and_panes = Join.join(:pid, services.tmux.panes, tree)
        pane_join = proc_and_panes.first
        return nil unless pane_join

        # new method on join: let's you get an underlying
        # object out of the join if it matches a predicate.
        return pane_join.unjoin do |o|
          o.is_a? ::Appear::Tmux::Pane
        end
      end

      def find_or_create_ide(filename)
        # remember that this can be nil
        nvim = find_nvim
        pane = nil
        if nvim
          pane = find_tmux_pane(nvim)
        else
          # TODO: implement create_new_session
          nvim, pane = create_ide(filename)
        end

        if nvim.has_file?(filename)
          nvim.focus_file(filename)
          return nvim, pane
        end

        w, h = nvim.size
        if w > 100
          nvim.open_vsplit(filename)
        else
          nvim.open_tab(filename)
        end

        return nvim, pane
      end

      def create_ide(filename)
        tmux_session = services.tmux.sessions.first
        dir = project_root(filename)
        if tmux_session
          window = tmux_session.windows.find do |win|
            panes = win.panes
            panes.length == 1 && panes.first.pwd == dir
          end || tmux_session.new_window(
            # -c: current directory
            :c => dir
          )
        else
          tmux_session = services.tmux.new_session(
            # -c: current directory
            :c => project_root(filename)
          )
          window = tmux_session.windows.first
        end
        bottom_pane = window.panes.first
        top_pane = bottom_pane.split_pane(
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

        return find_nvim, top_pane
      end

      def call(filename)
        nvim, pane = find_or_create_ide(filename)

        # focuses the pane in the tmux session
        services.tmux.reveal_pane(pane)

        # gotta get a client
        client_pid = tmux_client_for_tree(processes.process_tree(nvim.pid))
        if client
          Appear.appear(client_pid)
        else
          term_gui = Appear::Terminals.get_active_terminal || Appear::ITerm2.new
          term_pane = term_gui.tmux_client_for_session(pane.session)
          term_gui.reveal_pane(term_pane)
        end
      end
    end
  end
end
