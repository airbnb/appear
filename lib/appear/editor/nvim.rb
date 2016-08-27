require 'appear/util/command_builder'
require 'appear/util/value_class'
require 'yaml'
require 'pathname'

module Appear
  module Editor
    # Raised if we have problems interacting with Nvim.
    class NvimError < ::Appear::Error
      attr_reader :from_err
      # @param msg [String]
      # @param from_err [Exception] pass in another error to wrap it in an
      #   NvimError.
      def initialize(msg, from_err = nil)
        super(msg)
        @from_err = from_err
      end
    end

    # Wraps nvim-remote to implement basic nvim support.
    # @see https://github.com/mhinz/neovim-remote
    #
    # I put this in my zshrc:
    # `export NVIM_LISTEN_ADDRESS="$HOME/.vim/sockets/vim-zsh-$$.sock"`
    # this opens a seperate nvim socket for each new Zsh shell. You'll still
    # get nvims trying to open the same socket if you use ctrl-z and fg and
    # stuff to manage 'em, but overall this solves needing command a bunch of
    # different things.
    class Nvim < Service
      # the `neovim-remote` command name
      NVR = 'nvr'.freeze
      NEOVIM = 'nvim'.freeze

      # the value to use for Vim buffers with no name. This is the UI value
      # that Vim usually shows.
      NO_NAME = "[No Name]".freeze

      # value class describing a vim pane.
      class Pane < Util::ValueClass
        # @return [Fixnum] vim tab number
        attr_reader :tab

        # @return [Fixnum] vim window number
        attr_reader :window

        # @return [Fixnum] vim buffer number
        attr_reader :buffer

        # @return [Hash<Symbol, String>] data about the buffer
        attr_reader :buffer_info
      end

      delegate :run, :runner

      # This constant maps logical name to a string of filename-modifiers, for
      # the vim fnamemodify() function. When we collect information about
      # buffers, we get each of these expansions applied to the buffer name.
      #
      # This mapping was copied from the BufExplorer vim plugin.
      BUFFER_FILENAME_EXPANSIONS = {
        :name => '',
        :absolute_path => ':p',
        :dirname => ':p:h',
        :relative_path => ':~:.',
        :relative_dirname => ':~:.:h',
        :shortname => ':t'
      }.freeze
      # order in which we pass these to vim.
      BUFFER_FILENAME_ORDER = BUFFER_FILENAME_EXPANSIONS.keys.freeze

      # @return [#to_s] path to the unix socket used to talk to Nvim
      attr_reader :socket

      # Find the appropriate Nvim session for a given filename. First, we try
      # to find a session actually editing this file. If none exists, we find
      # the session with the deepest CWD that contains the filename.
      #
      # @param filename [String]
      # @param deps [Hash] service dependencies. We require at least :runner
      def self.find_for_file(filename, deps = {})
        cwd_to_nvim = {}

        sockets.each do |sock|
          nvim = self.new(sock, deps)
          # if one of these is actually editing this file, return right away!
          return nvim if nvim.find_buffer(filename)
          cwd_to_nvim[nvim.cwd] = nvim
        end

        cwd_by_depth = cwd_to_nvim.keys.sort_by { |d| Pathname.new(d).each_filename.to_a.length }
        match = cwd_by_depth.find { |cwd| path_contains?(cwd, filename) }
        return cwd_to_nvim[match]
      end

      # List all the sockets found in ~/.vim/sockets.
      # I put this in my zshrc to make this work:
      # `export NVIM_LISTEN_ADDRESS="$HOME/.vim/sockets/vim-zsh-$$.sock"`
      # @return [Array<Pathname>]
      def self.sockets
        Dir.glob(File.expand_path('~/.vim/sockets/*.sock')).map {|fn| Pathname.new(fn) }
      end

      # Spawn a new NVIM instance, then connect to its socket.
      def self.edit_command(filename)
        ::Appear::Util::CommandBuilder.new(NEOVIM).args(filename)
      end

      # @param socket [#to_s] UNIX socket to use to talk to Nvim.
      def initialize(socket, svc = {})
        super(svc)
        @socket = socket
      end

      # evaluate a Vimscript expression
      #
      # @param vimstring [String] the expression, eg "fnamemodify('~', ':p')"
      # @return [Object] expression result, parsed as YAML.
      def expr(vimstring)
        parse_output_as_yaml(run(command.flag('remote-expr', vimstring).to_a))
      end

      # Perform a Vim command
      #
      # @param vimstring [String] the command, eg ":buffers"
      def cmd(vimstring)
        run(command.flag('c', vimstring).to_a)
      end

      # PID of the remote vim session
      #
      # @return [Fixnum]
      def pid
        expr('getpid()')
      end

      # Working directory of the remote vim session
      #
      # @return [Pathname]
      def cwd
        expr('getcwd()')
      end

      # Get all the Vim panes in all tabs.
      #
      # @return [Array<Pane>] data
      def panes
        all_buffers = get_buffers
        all_panes = []
        get_windows.each_with_index do |wins, tab_idx|
          wins.each_with_index do |buffer, win_idx|
            all_panes << Pane.new(
              # in Vim, tabs and windows start indexing at 1
              :tab => tab_idx + 1,
              :window => win_idx + 1,
              :buffer => buffer,
              :buffer_info => all_buffers[buffer - 1]
            )
          end
        end
        all_panes
      end

      def find_buffer(filename)
        p = Pathname.new(filename).expand_path.to_s
        get_buffers.find do |buffer|
          res = buffer[:absolute_path] == p
        end
      end

      def to_s
        "#<#{self.class.name}:0x#{'%x' % (object_id << 1)} in #{cwd.inspect}>"
      end

      private

      def command
        ::Appear::Util::CommandBuilder.new(NVR).flags(:servername => @socket.to_s)
      end

      # Vimscript return values look vaguely like YAML, so parse them with
      # YAML.
      # @param output [String]
      def parse_output_as_yaml(output)
        begin
          return YAML.load(output)
        rescue => err
          raise NvimError.new(output, err)
        end
      end

      def get_windows
        expr(%Q[map( range(1, tabpagenr('$')), "tabpagebuflist(v:val)" )])
      end

      def get_buffers
        cmd = BUFFER_FILENAME_ORDER.map do |type|
          "fnamemodify(bufname(v:val), '#{BUFFER_FILENAME_EXPANSIONS[type]}')"
        end.join(', ')

        as_a = expr(%Q(map( range(1, bufnr('$')), "[v:val, #{cmd} ]" )))
        as_a.map do |row|
          buf = {:buffer => row.shift}
          row.each_with_index do |it, i|
            buf[BUFFER_FILENAME_ORDER[i]] = it
          end
          buf[:name] = NO_NAME if buf[:name].empty?
          buf
        end
      end

      # as dumb as they come
      def self.path_contains?(parent, child)
        p, c = Pathname.new(parent), Pathname.new(child)
        c.expand_path.to_s.start_with?(p.expand_path.to_s)
      end
    end
  end
end
