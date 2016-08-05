require 'appear/constants'
require 'appear/service'

module Appear
  class DeadProcess < Error; end

  # The Processes service handles looking up information about a system
  # process. It mostly interacts with the `ps` system utility.
  class Processes < Service
    delegate :run, :runner

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
      @cache = {}
    end

    def get_info(pid)
      result = @cache[pid]
      unless result
        result = fetch_info(pid)
        @cache[pid] = result
      end
      result
    end

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
      while tree.last.pid > 1
        tree << get_info(tree.last.parent_pid)
      end
      tree
    end

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
      output = run(['ps', '-p', pid.to_s, '-o', 'ppid=,command='])
      ppid, *command = output.strip.split(/\s+/).reject(&:empty?)
      name = File.basename(command.first)
      ProcessInfo.new({:pid => pid.to_i, :parent_pid => ppid.to_i, :command => command, :name => name})
    end
  end
end
