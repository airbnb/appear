require 'appear_mocks'
require 'appear/runner'
require 'appear/processes'
require 'open3'

RSpec.describe(Appear::Processes) do
  let (:output) { AppearMocks::Output.new }
  let (:runner) { Appear::Runner.new(:output => output) }
  let (:subprocess) { Open3.popen2e('cat') }
  let (:pid)    { Process.pid }
  subject { described_class.new(:output => output, :runner => runner) }

  describe '#alive?' do
    it 'true when pid alive' do
      expect(subject.alive?(pid)).to be(true)
    end

    it 'false when pid dead' do
      child = Process.fork { exit 1 }
      Process.wait(child)
      expect(subject.alive?(child)).to be(false)
    end
  end

  describe '#get_info' do
    it 'result has expected attrs' do
      i, o, info = Open3.popen2e('cat')
      result = subject.get_info(info.pid)
      expect(result.pid).to eq(info.pid)
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
      i, o, info = Open3.popen2e('cat')
      result = subject.process_tree(info.pid)

      # kill it off
      i.close
      info.kill

      expect(result.length).to be >= 2
    end
  end
end
