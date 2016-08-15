require 'appear/service'
require 'appear/memoizer'

module Appear
  # raised if we can't parse a connection from an output line of the `lsof`
  # command.
  class LsofParseError < Appear::Error; end

  # The LSOF service co-ordinates access to the `lsof` system utility.  LSOF
  # stands for "list open files". It can read the "connections" various
  # programs have to a given file, eg, what programs have a file descriptor for
  # a file.
  class Lsof < Service
    attr_reader :cache

    delegate :run, :runner

    # A connection of a process to a file.
    # Created from one output row of `lsof`.
    class Connection
      attr_accessor :command_name, :pid, :user, :fd, :type, :device, :size, :node, :name, :file_name
      def initialize(hash)
        hash.each do |key, value|
          raise LsofParseError.new("attr #{key.inspect} is nil") if value.nil?
          send("#{key}=", value)
        end
      end
    end

    # Represents a pane's connection to a TTY.
    class PaneConnection
      attr_reader :pane, :connection, :process
      # @param pane [#tty] a pane in a terminal emulator
      # @param connection [Appear::Lsof::Connection] a connection of a process
      #   to a file -- usually a TTY device.
      # @param process [Appear::Processes::ProcessInfo] a process
      def initialize(pane, connection, process)
        @pane = pane
        @connection = connection
        @process = process
      end

      # @return [String] the TTY this connection is to
      def tty
        connection.file_name
      end

      # @return [Fixnum] pid of the process making the connection
      def pid
        connection.pid
      end
    end

    def initialize(*args)
      super(*args)
      @lsof_memo = Memoizer.new
    end

    # find any intersections where a process in the given tree is present in
    # one of the terminal emulator panes. Performs an LSOF lookup on the TTY of
    # each pane. Returns cases where one of the panes' ttys also have a
    # connection from a process in the process tree.
    #
    # This is much faster if each pane includes a .pids method that returns an
    # array of PIDs that could be the PID of the terminal emulator with that pane
    #
    # @param tree [Array<Process>]
    # @param panes [Array<Pane>]
    # @return [Array<PaneConnection>]
    def join_via_tty(tree, panes)
      hitlist = {}
      tree.each do |process|
        hitlist[process.pid] = process
      end

      ttys = panes.map(&:tty)
      if panes.all? {|p| p.respond_to?(:pids) }
        pids = hitlist.keys + panes.map(&:pids).flatten
        lsofs = lsofs(ttys, :pids => pids)
      else
        lsofs = lsofs(ttys)
      end

      hits = {}
      panes.each do |pane|
        connections = lsofs[pane.tty]
        connections.each do |conn|
          process = hitlist[conn.pid]
          if process
            hits[conn.pid] = PaneConnection.new(pane, conn, process)
          end
        end
      end

      hits.values
    end

    # list connections to files.
    #
    # @param files [Array<String>] files to query
    # @return [Hash<String, Array<Connection>>] map of filename to connections
    def lsofs(files, opts = {})
      mutex = Mutex.new
      results = {}
      threads = files.map do |file|
        Thread.new do
          single_result = lsof(file, opts)
          mutex.synchronize do
            results[file] = single_result
          end
        end
      end
      threads.each { |t| t.join }
      results
    end

    private

    def lsof(file, opts = {})
      error_line = nil
      @lsof_memo.call(file, opts) do
        pids = opts[:pids]
        if pids
          output = run(['lsof', '-ap', pids.join(','), file], :allow_failure => true)
        else
          output = run(['lsof', file], :allow_failure => true)
        end
        next [] if output.empty?
        rows = output.lines.map do |line|
          error_line = line
          command, pid, user, fd, type, device, size, node, name = line.strip.split(/\s+/)
          Connection.new({
            command_name: command,
            pid: pid.to_i,
            user: user,
            fd: fd,
            type: type,
            device: device,
            size: size,
            node: node,
            file_name: name
          })
        end
        rows[1..-1]
      end
    rescue LsofParseError => err
      log("lsof: parse error: #{err}, line: #{error_line}")
      []
    end
  end
end
