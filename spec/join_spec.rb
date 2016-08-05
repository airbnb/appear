require 'appear/join'

RSpec.describe(Appear::Join) do
  class Thing
    attr_reader :prop
    def initialize(prop = 'a')
      @prop = prop
    end
  end

  subject { described_class.new(Thing.new) }

  describe '.can_access?' do
    it 'true when object has that field' do
      expect(described_class.can_access?(Thing.new, :prop)).to be(true)
    end

    it 'true when object has subscript operator' do
      expect(described_class.can_access?({}, :prop)).to be(true)
    end

    it 'false if that aint no thing' do
      expect(described_class.can_access?(Thing.new, :pbepis)).to be(false)
    end
  end

  describe '.access' do
    it 'can access methods' do
      expect(described_class.access(Thing.new, :prop)).to eq('a')
      expect(described_class.access(Thing.new('foo'), 'prop')).to eq('foo')
    end

    it 'can access via subscript' do
      expect(described_class.access({:foo => 'bar'}, :foo)).to eq('bar')
      expect(described_class.access({'ha' => 'haha'}, 'ha')).to eq('haha')
    end
  end

  describe '#[]' do
    it 'picks first non-nil field' do
      a = described_class.new(Thing.new(nil), Thing.new('a'), Thing.new('b'))
      expect(a[:prop]).to eq('a')

      b = described_class.new({:bar => 1}, {:foo => nil}, {:foo => 'true foo'})
      expect(b[:foo]).to eq('true foo')
    end

    it 'can access props via string' do
      expect(subject['prop']).to eq('a')
    end
  end

  describe '#method_missing' do
    it 'calls through to [] for access methods' do
      expect(subject).to receive(:[]).and_call_original
      expect(subject.prop).to eq('a')
    end

    it 'raises NoMethodError if it does not have given prop' do
      expect do
        subject.not_a_prop
      end.to raise_error(NoMethodError, /^Cannot access/)
    end

    context 'when called with arguments' do
      it 'fails with ArgumentError' do
        expect do
          subject.prop(1, 2)
        end.to raise_error(ArgumentError, /^Passed args to accessor/)

        expect do
          subject.prop { puts "should not run" }
        end.to raise_error(ArgumentError, /^Passed block to accessor/)
      end
    end
  end

  describe '.join' do
    let (:things) do
      [
        Thing.new('props_only'),
        Thing.new(1),
        Thing.new(2),
        Thing.new(3),
      ]
    end

    let (:other_data) do
      [
        {prop: 1, foo: 'bar'},
        {prop: 2, foo: 'quux'},
        {prop: 3, foo: 'bear'},
        {prop: 'other_data_only', foo: 'dog'},
      ]
    end

    it 'joins collections based on a field' do
      joined = described_class.join(:prop, things, other_data)

      one = joined.find {|row| row.prop == 1}
      two = joined.find {|row| row.prop == 2}
      three = joined.find {|row| row.prop == 3}

      expect(one.foo).to eq('bar')
      expect(two.foo).to eq('quux')
      expect(three.foo).to eq('bear')
    end

    it 'omits unjoined values in tables' do
      joined = described_class.join(:prop, things, other_data)
      expect(joined.find {|row| row.prop == 'other_data_only' }).to be_nil
      expect(joined.find {|row| row.prop == 'props_only' }).to be_nil
    end

    it 'can be joined again' do
      joined = described_class.join(:prop, things, other_data)
      new_data = [{prop: 2, new_data: 'hello world'}]
      rejoined = described_class.join(:prop, joined, new_data)

      expect(rejoined.size).to eq(1)
      expect(rejoined.first.new_data).to eq('hello world')
      expect(rejoined.first.foo).to eq('quux')
    end

    it 'earlier tables override later tables' do
      joined = described_class.join(:prop, things, other_data)
      new_data = [{prop: 2, new_data: 'hello world', foo: 'new data foo'}]

      joined_first = described_class.join(:prop, joined, new_data).first
      new_data_first = described_class.join(:prop, new_data, joined).first

      expect(joined_first.foo).to eq('quux')
      expect(new_data_first.foo).to eq('new data foo')
    end
  end
end
