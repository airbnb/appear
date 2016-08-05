# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'appear/constants'

Gem::Specification.new do |spec|
  spec.name          = "appear"
  spec.version       = Appear::VERSION
  spec.authors       = ["Jake Teton-Landis"]
  spec.email         = ["just.1.jake@gmail.com"]

  spec.summary       = %q{Appear your terminal programs in your gui!}
  spec.description   = <<-EOS
    Appear is a tool for revealing a given process in your terminal. Given a
    process ID, `appear` finds the terminal emulator view (be it a window, tab, or
    pane) containing that process and shows it to you. Appear understands terminal
    multiplexers like `tmux`, so if your target process is in a multiplexer
    session, `appear` will reveal a client connected to that session, or start one
    if needed.

    This project intends to support all POSIX operating systems eventually, but
    currently only supports macOS.
  EOS
  spec.homepage      = "https://github.com/airbnb/appear"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "yard"
end
