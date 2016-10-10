require "bundler/gem_tasks"
require "yard"
require 'rspec/core/rake_task'
require 'appear'
require 'Open3'
require 'fileutils'


RSpec::Core::RakeTask.new(:spec)
ROOT_PATH = Pathname.new(File.dirname(File.expand_path(__FILE__)))

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

class IdeAppBuilder
  NAME = 'TmuxIde'

  def initialize(opts = {})
    @release = opts[:release] || false
  end

  def development?
    !@release
  end

  def base
    ::Appear::Util::CommandBuilder.new('platypus')
  end

  def suffixes
    %w(
    rb
    )
  end

  # see https://developer.apple.com/library/prerelease/content/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html
  def utis
    %w(
    public.source-code
    public.item
    public.folder
    )
  end

  def command
    cmd = base.flags(
      :name => NAME,
      'interface-type' => 'None',
      'app-icon' => assets_dir.join('MacVim.icns'),
      'document-icon' => assets_dir.join('MacVim-generic.icns'),
      :interpreter => '/usr/bin/ruby',
      'app-version' => ::Appear::VERSION,
      :author => 'Jake Teton-Landis',
      'bundle-identifier' => "tl.jake.#{NAME}",
      :droppable => true,
      'quit-after-execution' => true,
      :suffixes => suffixes.join('|'),
      'uniform-type-identifiers' => utis.join('|'),
    )

    cmd.flags(:symlink => true) if development?

    # read script from STDIN,
    # build to build/TmuxIde.app
    cmd.args(
      ROOT_PATH.join('tools/app-main.rb'),
      output_app
    )

    cmd
  end

  def assets_dir
    ROOT_PATH.join('assets')
  end

  def build_dir
    ROOT_PATH.join('build')
  end

  def output_app
    build_dir.join("#{NAME}.app")
  end

  def resources
    output_app.join('Contents/Resources')
  end

  def app_gem
    resources.join('appear-gem')
  end

  def files
    %w(bin lib tools appear.gemspec Gemfile Gemfile.lock)
  end

  def link_files!
    files.each do |name|
      src = ROOT_PATH.join(name)
      dest = app_gem.join(name)
      FileUtils.ln_s(src, dest)
    end
  end

  def copy_files!
    files.each do |name|
      src = ROOT_PATH.join(name)
      dest = app_gem.join(name)
      FileUtils.cp_r(src, dest)
    end
  end

  def run!
    FileUtils.rm_rf(build_dir)
    FileUtils.mkdir_p(build_dir)

    # build the app with platypus
    args = command.to_a
    puts args
    out, err, status = Open3.capture3(*args)
    puts out unless out.empty?
    raise err unless status.success?

    # copy or link gem files into place
    FileUtils.mkdir_p(app_gem)
    if development?
      link_files!
    else
      copy_files!
    end
  end
end

desc "build a mac app that can appear stuff"
task :app do
  builder = IdeAppBuilder.new
  builder.run!
end

BasicDocCoverage.define_task(:doc)

task default: [:spec, :doc]
