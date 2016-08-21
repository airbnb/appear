require 'shellwords'
require 'pathname'
require 'open3'
require 'appear/util/command_builder'
require 'yaml'

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

    # Wraps nvim-remote to implement basoc nvim support.
    # @see https://www.facebook.com/events/1571719799798071/
    #
    # I put this in my zshrc:
    # `export NVIM_LISTEN_ADDRESS="$HOME/.vim/sockets/vim-zsh-$$.sock"`
    # this opens a seperate nvim socket for each new Zsh shell. You'll still
    # get nvims trying to open the same socket if you use ctrl-z and fg and
    # stuff to manage 'em, but overall this solves needing command a bunch of
    # different things.
    class Nvim < Service
      COMMAND = 'nvr'
      NO_NAME = "[No Name]".freeze

      attr_reader :socket

      def self.find_for_file(filename)
        socket = sockets.find do |sock|
          nvim = self.new(sock)
          path_contains?(nvim.cwd, filename)
        end

        return self.new(socket) if socket
      end

      def self.sockets
        Dir.glob(File.expand_path('~/.vim/sockets/*.sock')).map {|fn| Pathname.new(fn) }
      end

      def initialize(socket)
        @socket = socket
      end

      def command
        ::Appear::Util::CommandBuilder.new(COMMAND).flags(:servername => @socket.to_s)
      end

      def run(cmd_inst)
        stdout, status = Open3.capture2e(*cmd_inst.to_a)
        stdout
      end

      def expr(vimstring)
        run(command.flag('remote-expr', vimstring))
      end

      def cmd(vimstring)
        run(command.flag('c', vimstring))
      end

      def pid
        expr('getpid()').strip.to_i
      end

      def cwd
        Pathname.new(expr('getcwd()').strip)
      end

      def open_tab(filename)
        cmd("tabe #{filename}")
      end

      def open_vsplit(filename)
        cmd("vsplit #{filename}")
      end

      def open_hsplit(filename)
        cmd("split #{filename}")
      end

      def panes
        all_buffers = bufs2
        all_panes = []
        get_all_wins.each_with_index do |wins, tab|
          wins.each_with_index do |buff, win|
            all_panes << {
              # in Vim, tabs and windows start indexing at 1
              :tab => tab + 1,
              :window => win + 1,
              :buffer => buff,
              :buffer_info => all_buffers[buff - 1]
            }
          end
        end
        all_panes
      end

      def get_tabs
        expr(
          %w(range(1, tabpagenr('$')))
        )
      end

      def get_all_wins
        YAML.load(expr(%Q[map( range(1, tabpagenr('$')), "tabpagebuflist(v:val)" )]).strip)
      end

      def bufs
        get_all_wins.flatten.uniq
      end

      def bufs2
        # taken from BufExplorer
        types = {
          "name" => '',
          "fullname" => ':p',
          "path" => ':p:h',
          "relativename" => ':~:.',
          "relativepath" => ':~:.:h',
          "shortname" => ':t'
        }
        types_order = types.keys.sort
        cmd = types_order.map do |type_name|
          "fnamemodify(bufname(v:val), '#{types[type_name]}')"
        end.join(', ')

        output = expr(%Q(map( range(1, bufnr('$')), "[v:val, #{cmd} ]" )))
        as_a = YAML.load(output)
        as_a.map do |row|
          buf = {:buffer => row.shift}
          row.each_with_index do |it, i|
            buf[types_order[i].to_sym] = it
          end
          buf[:name] = NO_NAME if buf[:name].empty?
          buf
        end
      end

      # this is a little weird - sometimes the screen flashes briefly
      # and, it is slow
      # and, it needs parsing
      def buf_info
        cmd("redir => appear_buflist_var")
        cmd("buffers!")
        cmd("redir END")
        output = expr('appear_buflist_var')
        output.split("\n").reject(&:empty?).map do |line|
          bits, *name, loc = line.split('"')
          num = bits.match(/\d+/)
          num = num[0].to_i if num
          name = name.join('"')
          loc = loc.strip.split(' ').last.to_i if loc
          {
            num: num,
            name: name,
            bits: bits,
            line: loc
          }
        end
      end

      def bufs_2_paths(list)
        expr(%Q(map( #{list.to_json}, "fnamemodify(bufname(v:val), ':p')" )))
      end

      private

      # as dumb as they come
      def self.path_contains?(parent, child)
        child.to_s.start_with?(parent.to_s)
      end
    end

    class TmuxIde
      # @return [Appear::Editor::Nvim, nil] an nvim editor session suitable for
      #   opeing files, or nil if nvim isn't running or there are no suitable sessions.
      def find_nvim
        raise NotImplemented
      end

      # find the tmux pane holding an nvim editor instance.
      #
      # @param nvim [Appear::Editor::Nvim]
      # @return [Appear::Tmux::Pane, nil] the pane, or nil if not found
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

        return find_nvim(filename), top_pane
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
