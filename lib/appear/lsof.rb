require 'appear/service'
require 'pry'

module Appear
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
          send("#{key}=", value)
        end
      end
    end

    # TODO: replace with a Join?
    class PaneConnection
      attr_reader :pane, :connection, :process
      # @param pane [#tty] a pane in a terminal emulator
      # @param connection [Appear::Lsof::Connection] a connection of a process
      # to a file -- usually a TTY device.
      # @param process [Appear::Processes::ProcessInfo] a process
      def initialize(pane, connection, process)
        @pane = pane
        @connection = connection
        @process = process
      end

      def tty
        connection.file_name
      end

      def pid
        connection.pid
      end
    end

    def initialize(*args)
      super(*args)
      @cache = {}
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
    # @return Array<PaneConnection>
    def join_via_tty(tree, panes)
      hitlist = {}
      tree.each do |process|
        hitlist[process.pid] = process
      end

      ttys = panes.map(&:tty)
      if panes.all? {|p| p.respond_to?(:pids) }
        puts "using pids in join_via_tty"
        pids = hitlist.keys + panes.map(&:pids).flatten
        # binding.pry
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

    # list connections to files
    # @param files [Array<String>] files to query
    # @return Hash<String, Array<Connection>> - map of filename to connections
    def lsofs(files, opts = {})
      cached = files.select { |f| @cache[f] }
      uncached = files.reject { |f| @cache[f] }

      result = parallel_lsof(uncached, opts)
      result.each do |file, data|
        @cache[file] = data
      end

      cached.each do |f|
        result[f] = @cache[f]
      end

      result
    end

    private

    # lsof takes a really long time, so parallelize lookups when you can.
    def parallel_lsof(files, opts = {})
      results = {}
      threads = files.map do |file|
        Thread.new do
          results[file] = lsof(file, opts)
        end
      end
      threads.each { |t| t.join }
      results
    end

    def lsof(file, opts = {})
      pids = opts[:pids]
      if pids
        output = run(['lsof', '-ap', pids.join(','), file])
      else
        output = run("lsof #{file.shellescape}")
      end
      rows = output.lines.map do |line|
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
    rescue Appear::ExecutionFailure
      []
    end
  end
end
