require 'appear/constants'
require 'appear/service'

module Appear
  # Raised if Processes tries to get info for a dead process, or a PID that is
  # otherwise not found.
  class DeadProcess < Error; end

  # The Processes service handles looking up information about a system
  # process. It mostly interacts with the `ps` system utility.
  class Processes < Service
    delegate :run, :runner

    # contains information about a process. Returned by Processes#get_info and
    # its derivatives.
    class ProcessInfo
      attr_accessor :pid, :command, :name, :parent_pid
      def initialize(hash)
        hash.each do |key, value|
          send("#{key}=", value)
        end
      end
    end

    def initialize(*args)
      super(*args)
      @get_info_memo = Memoizer.new
    end

    # Get info about a process by PID, including its command and parent_pid.
    #
    # @param pid [Integer]
    # @return [ProcessInfo]
    def get_info(pid)
      @get_info_memo.call(pid) do
        fetch_info(pid)
      end
    end

    # Is the given process alive?
    #
    # @param pid [Integer]
    # @return [Boolean]
    def alive?(pid)
      begin
        ::Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end
    end

    # look up all the processes between the given pid and PID 1
    # @param pid [Number]
    # @return [Array<ProcessInfo>]
    def process_tree(pid)
      tree = [ get_info(pid) ]
      while tree.last.pid > 1 && tree.last.parent_pid != 0
        tree << get_info(tree.last.parent_pid)
      end
      tree
    end

    # @param pattern [String]
    # @return [Array<Integer>] pids found
    def pgrep(pattern)
      output = run(['pgrep', '-lf', pattern])
      output.lines.map do |line|
        line.strip.split(/\s+/).first.to_i
      end
    rescue Appear::ExecutionFailure
      []
    end

    private

    def fetch_info(pid)
      raise DeadProcess.new("cannot fetch info for dead PID #{pid}") unless alive?(pid)
      output = run(['ps', '-p', pid.to_s, '-o', 'ppid=', '-o', 'command='])
      ppid, *command = output.strip.split(/\s+/).reject(&:empty?)
      name = File.basename(command.first)
      ProcessInfo.new({:pid => pid.to_i, :parent_pid => ppid.to_i, :command => command, :name => name})
    end
  end
end
