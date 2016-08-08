require 'appear_mocks'
require 'appear/runner'
require 'appear/processes'
require 'open3'

RSpec.describe(Appear::Processes) do
  let (:output) { AppearMocks::Output.new }
  let (:runner) { Appear::Runner.new(:output => output) }
  let (:pid)    { Process.pid }

  subject { described_class.new(:output => output, :runner => runner) }

  # print the version of ps
  before :all do
    puts "ps version:"
    system('ps --version')
  end

  # sometimes we want to use a subprocess of cat, but we don't want to remember
  # to clean it up. But, we don'\t want to do unnecessary cleanups if we didn't
  # use subprocess. soooo
  before :each do
    @used_cat = false
  end

  let (:cat) do
    @used_cat = true
    Open3.popen2e('cat')
  end

  let (:cat_info) do
    *, thread = cat
    thread
  end

  def kill_cat
    i, o, info = cat
    begin
      Process.kill('KILL', info.pid)
      # wait for exactly cat_info.pid
      Process.wait(cat_info.pid, 1)
    rescue Errno::ESRCH, Errno::ECHILD
      # we get these errors if the process is already dead, in which case, we
      # don't care at all.
      nil
    end
  end

  after :each do
    kill_cat if @used_cat
  end

  describe '#alive?' do
    it 'true when pid alive' do
      expect(subject.alive?(pid)).to be(true)
    end

    it 'false when pid dead' do
      kill_cat
      expect(subject.alive?(cat_info.pid)).to be(false)
    end
  end

  describe '#get_info' do
    it 'result has expected attrs' do
      result = subject.get_info(cat_info.pid)

      expect(result.pid).to eq(cat_info.pid)
      expect(result.name).to eq('cat')
      expect(result.command).to eq(['cat'])
      expect(result.parent_pid).to eq(pid)
    end

    it 'caches results' do
      a = subject.get_info(pid)
      b = subject.get_info(pid)

      expect(a).to be(b)
    end
  end

  describe '#process_tree' do
    it 'returns many results' do
      result = subject.process_tree(cat_info.pid)
      expect(result.length).to be >= 2
    end
  end
end
