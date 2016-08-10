require 'appear'
RSpec.describe Appear do
  subject do
    Appear
  end

  let :instance do
    Appear::Instance.new(Appear::Config.new)
  end

  describe '.appear' do
    it 'can appear' do
      expect(Appear::Instance).to receive(:new).and_return(instance)
      expect(instance).to receive(:call).with(1)

      subject.appear(1)
    end

    it 'can appear with config' do
      config = Appear::Config.new

      expect(Appear::Instance).to receive(:new).with(config).and_return(instance)
      expect(instance).to receive(:call).with(1)

      subject.appear(1, config)
    end
  end

  describe '.build_command' do
    it 'builds a command string' do
      expect(subject.build_command(1)).to match(/appear 1$/)
    end

    it 'builds with options if config provided' do
      config = Appear::Config.new
      config.silent = false
      config.log_file = 'foo'
      expect(subject.build_command(1, config)).to match(/appear 1 --verbose --log-file foo$/)
    end
  end
end
