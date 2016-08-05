require 'appear_mocks'
require 'appear/runner'

RSpec.describe(Appear::Runner) do
  let (:output) { AppearMocks::Output.new }
  subject { described_class.new(:output => output) }

  describe '#run' do
    context 'when command is array' do
      let (:command) { %w(echo hello) }
      let (:bad) { %w(false) }

      it 'returns command result' do
        expect(subject.run(command)).to eq("hello\n")
      end

      it 'raises error if command fails' do
        expect do
          subject.run(bad)
        end.to raise_error(Appear::ExecutionFailure, /failed with output/)
      end
    end

    context 'when command is a string' do
      let (:command) { 'echo hello' }
      let (:bad) { 'false' }

      it 'returns command result' do
        expect(subject.run(command)).to eq("hello\n")
      end

      it 'raises error if command fails' do
        expect do
          subject.run(bad)
        end.to raise_error(Appear::ExecutionFailure, /failed with output/)
      end
    end
  end
end
