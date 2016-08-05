require 'appear_mocks'
require 'appear/runner'
require 'appear/processes'

RSpec.describe(Appear::Processes) do
  let (:output) { AppearMocks::Output.new }
  let (:runner) { Appear::Runner.new(:output => output) }
  let (:pid)    { Process.pid }
  subject { described_class.new(:output => output, :runner => runner) }

  it 'what is travis doing?' do
    puts "pid of this process: #{pid}"
  end

  describe '#alive?' do
    it 'true when pid alive' do
      expect(subject.alive?(::Process.pid)).to be(true)
    end

    it 'false when pid dead' do
      child = Process.fork { exit 1 }
      Process.wait(child)
      expect(subject.alive?(child)).to be(false)
    end
  end

  describe '#get_info' do
    it 'result has expected attrs' do
      result = subject.get_info(pid)
      expect(result.pid).to eq(pid)
      expect(result.name).to ba_a(String)
      expect(result.command).to be_a(Array)
      expect(result.parent_pid).to be_a(Fixnum)
    end

    it 'caches results' do
      a = subject.get_info(pid)
      b = subject.get_info(pid)

      expect(a).to be(b)
    end
  end

  describe '#process_tree' do
    it 'returns many results' do
      result = subject.process_tree(pid)
      expect(result.length).to be >= 2
    end
  end
end
