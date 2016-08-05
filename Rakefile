require "bundler/gem_tasks"
require "yard"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

module BasicDocCoverage
  MINIMUM_COVERAGE = 25.0
  YARD_COVERAGE_REGEX = /\s(?<percent>[\d\.]+)% documented/

  ROOT_PATH = Pathname.new(File.dirname(File.expand_path(__FILE__)))
  MINIMUM_COVERAGE_FILE = ROOT_PATH.join('.doc-coverage')

  def self.define_task(task_name)
    YARD::Rake::YardocTask.new(task_name) do |t|
      t.files = ['lib/**/*.rb', '-', 'README.md']
      t.options = ['--protected', '--no-private']

      # make sure we doc the things
      t.after = proc do

        min_coverage = MINIMUM_COVERAGE
        if MINIMUM_COVERAGE_FILE.exist?
          min_coverage = [min_coverage, MINIMUM_COVERAGE_FILE.read.strip.to_f].max
        end

        yard_result = `bundle exec yard stats --list-undoc`
        match = YARD_COVERAGE_REGEX.match(yard_result)
        if !match
          raise "Could not determine doc coverage using RE #{RE} from YARD output\n" \
            ">>> start YARD output\n#{yard_result}\n<<< end YARD output"
        end

        percent = match[:percent].to_f
        failure = percent < min_coverage

        if failure
          raise "FAILURE: doc coverage percent #{percent} < #{min_coverage}\n" \
            "  please write good docs for your methods and attributes!\n" \
            "  run `bundle exec yard stats --list-undoc` for details"
        else
          puts "SUCCESS: doc coverage percent #{percent} >= #{min_coverage}"
        end

        File.write(MINIMUM_COVERAGE_FILE, [percent, min_coverage].max.to_s)
      end
    end
  end
end

BasicDocCoverage.define_task(:doc)

task default: [:spec, :doc]
