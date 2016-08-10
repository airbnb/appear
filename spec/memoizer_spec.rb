require 'appear/memoizer'
RSpec.describe Appear::Memoizer do
  describe '#call' do
    it 'memoizes calls with the same arguments' do
      value = 0
      arg = 'foo'
      2.times do
        subject.call(arg) do
          value += 1
        end
      end

      expect(value).to eq(1)
    end

    it 'returns the result from first call with that argument' do
      did_call = false
      subject.call() do
        next "second call" if did_call
        did_call = true
        next "first call"
      end
      expect(subject.call() {}).to eq("first call")
    end

    it 'returns different results for different params' do
      a = subject.call('a') { 1 }
      b = subject.call('b') { 2 }
      expect(a).to eq(1)
      expect(b).to eq(2)
    end

    it 'raises if no block given' do
      expect do
        subject.call()
      end.to raise_error(ArgumentError, /no block given/)
    end
  end
end
