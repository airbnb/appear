require 'pathname'
require 'json'
require 'appear/constants'
require 'appear/service'
require 'appear/runner'

module AppearMocks
  class Service < Appear::BaseService
    def initialize
      super({})
    end
  end

  class Runner < Service
    def run(command); end
  end

  class Output < Service
    def log(*args); end
    def output(*args); end
    def log_error(err); end
  end

  class PlaybackRunner
    def initialize(db)
      # DO NOT MODIFY THIS DB THING!!!!
      @db = db
      @current_index = Hash.new { |h, k| h[k] = 0 }
    end

    def run(command)
      output = get_next(command)
      if output['status'] == 'success'
        return output['output']
      else
        raise Appear::ExecutionFailure.new(command, output['output'])
      end
    end

    def skip(command)
      get_next(command)
      nil
    end

    private

    def get_next(command)
      outputs = @db[command]
      raise 'no outputs for the given command' unless outputs
      current_index = @current_index[command]
      output = outputs[current_index]
      raise 'no outputs remaining for the given command' unless output

      @current_index[command] += 1
      output
    end
  end

  class PlaybackData
    INPUT_DIR = Appear::MODULE_DIR.join('spec/command_output')

    def initialize
      @db = Hash.new { |h, k| h[k] = [] }
    end

    def load(glob)
      files = Pathname.glob(INPUT_DIR.join(glob))
      files.each do |f|
        data = JSON.load(f.read)
        hydrate_time_field(data, 'record_at')
        hydrate_time_field(data, 'init_at')
        @db[data['command']] << data
        @db[data['command']].sort_by! { |c| c[:record_at] }
      end
      self
    end

    def runner
      PlaybackRunner.new(@db)
    end

    private

    def hydrate_time_field(hash, field)
      val = hash[field]
      if val
        time = Time.parse(val)
        hash[field] = time
      end
    end
  end
end
