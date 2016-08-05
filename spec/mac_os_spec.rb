require 'appear_mocks'
require 'appear/mac_os'

RSpec.describe(Appear::MacOs) do
  WAT = AppearMocks::PlaybackData.new.load('*macOs-helper.js-run*.json')
  let (:output) { AppearMocks::Output.new }
  let (:runner) { WAT.runner }
  subject do
    described_class.new(:output => output, :runner => runner)
  end

  describe '#call_method' do

    # TODO: some PlaybackData based tests for all systems

    context 'integration tests' do
      before do
        # skip all these specs if the runner is not a Mac, because this class
        # requires OSA-Script
        skip('Requires macOS >= 10.10') unless /darwin/ =~ RUBY_PLATFORM
      end

      # use a real runner for these integration tests
      let (:runner) { Appear::Runner.new(:output => output) }

      it 'returns the result value' do
        expect(subject.call_method('test_ok', {'hello' => 'world'})).
          to eq({'hello' => 'world'})
        expect(subject.call_method('test_ok', 5)).
          to eq(5)
      end

      it 'raises error on error' do
        expect do
          subject.call_method('test_err')
        end.to raise_error(Appear::MacToolError, /testing error handling/)
      end
    end
  end
end
