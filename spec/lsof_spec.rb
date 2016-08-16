require 'appear_mocks'
require 'appear/lsof'

RSpec.describe Appear::Lsof do
  RUN_DATA = AppearMocks::PlaybackData.new.load('*lsof-run*.json')
  let (:output) { AppearMocks::Output.new }
  let (:runner) { RUN_DATA.runner }
  subject do
    described_class.new(:output => output, :runner => runner)
  end

  describe '#initialize' do
    it 'raises ArgumentError unless all deps provided' do
      expect do
        described_class.new
      end.to raise_error(ArgumentError, /required service/)

      described_class.new(:output => output, :runner => runner)
    end
  end

  describe '#lsofs' do
    # this is a shitty test for now, just to make sure that all the playback
    # stuff is working!
    it 'works correctly' do
      ttys = %w(/dev/ttys003 /dev/ttys005)
      result = subject.lsofs(ttys)
      expect(result.keys.length).to eq(2)
      tty3, tty5 = result.values_at(*ttys)

      expect(tty3).to be_a(Array)
      expect(tty5).to be_a(Array)
    end
  end
end
