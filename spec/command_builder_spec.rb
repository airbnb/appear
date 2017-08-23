require 'appear/util/command_builder'

RSpec.describe Appear::Util::CommandBuilder do
  let (:cmd) { 'foo' }
  subject { described_class.new(cmd) }

  describe '#flags' do
    it 'adds flags to the command' do
      expect(subject.flags(:a => true, :b => 1, :bark => 'cow').to_s).
        to eq('foo -a -b 1 --bark cow')
    end
  end

  describe '#args' do
    it 'adds args to the command' do
      expect(subject.args('one', 2, 'three').to_s).
        to eq('foo one 2 three')
    end
  end

  describe '#initialize' do
    it 'supports :single_dash_long_flags' do
      s = described_class.new(cmd, :single_dash_long_flags => true)
      s.flags(:some => true, :flags => 'foo-bar').args('a', 'b')
      expect(s.to_s).to eq("#{cmd} -some -flags foo-bar a b")
    end

    it 'supports :dashdash_after_flags' do
      s = described_class.new(cmd, :dashdash_after_flags => true)
      s.flags(:a => true, :b => true)
      s.args(1, 2)
      expect(s.to_s).to eq("#{cmd} -a -b -- 1 2")
    end

    it 'supports multi-word commands' do
      s = described_class.new(['vagrant', 'provision'])
      s.flags(:provider => 'amiga').args('foo', 'bar')
      expect(s.to_s).to eq('vagrant provision --provider amiga foo bar')
    end
  end

  describe '#subcommand' do
    it 'can nest flags and such' do
      subject.flags(:parent => 'yep').subcommand('bar') do |bar|
        bar.flags(:child => 'cow').args(1, 2)
      end
      expect(subject.to_s).to eq('foo --parent yep bar --child cow 1 2')
    end
  end

  describe '#==' do
    it 'overrides the == method properly' do
      cmd1 = described_class.new('command name').flags(:parent => 'yep').args(1, 2)
      cmd2 = described_class.new('command name').flags(:parent => 'yep').args(1, 2)
      expect(cmd1).to be == cmd2
    end
  end
end
