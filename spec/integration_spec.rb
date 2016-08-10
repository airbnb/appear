# This spec runs the command to reveal the current process!
require "open3"
require 'appear/constants'


RSpec.describe("appear binary") do
  BINARY = Appear::MODULE_DIR.join('bin/appear').to_s

  it "runs with no arguments" do
    *, status = Open3.capture3(BINARY)
    expect(status.exitstatus).to satisfy { |exit| exit == 0 || exit == 2 }
  end

  it "runs with an int argument" do
    *, status = Open3.capture3(BINARY, Process.pid.to_s)
    expect(status.exitstatus).to satisfy { |exit| exit == 0 || exit == 2 }
  end

  it "fails when passed a string" do
    *, status = Open3.capture3(BINARY, "foo")
    expect(status.exitstatus).to be(1)
  end
end
