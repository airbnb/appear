require 'appear/util/value_class'

RSpec.describe Appear::Util::ValueClass do
  class Parent < described_class
    property :parent_prop
    property :huh?, var: :huh_var
  end

  class Child < Parent
    property :child_prop
  end

  describe '.properties' do
    it 'lists all properties on the value class' do
      expect(Parent.properties).to eq([:parent_prop, :huh_var])
    end

    it 'includes props from parent classes' do
      expect(Child.properties).to eq([:parent_prop, :huh_var, :child_prop])
    end
  end

  describe '#initialize' do
    it 'requires that all properties are defined' do
      expect do
        Parent.new(:parent_prop => 1)
      end.to raise_error(described_class::MissingValueError, /huh_var/)

      expect do
        Parent.new(:huh_var => 1)
      end.to raise_error(described_class::MissingValueError, /parent_prop/)

      instance = Parent.new(:parent_prop => 1, :huh_var => 2)
    end

    it 'includes props from parent class' do
      expect do
        Child.new(:child_prop => 1)
      end.to raise_error(described_class::MissingValueError, /parent_prop/)

      instance = Child.new(:child_prop => 1, :parent_prop => 2, :huh_var => 3)
    end

    it 'sets property values' do
      child = Child.new(:child_prop => 1, :parent_prop => 2, :huh_var => 3)
      expect(child.parent_prop).to eq(2)
      expect(child.huh?).to eq(3)
      expect(child.child_prop).to eq(1)
    end
  end
end
