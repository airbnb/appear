require 'json'

require 'appear/constants'
require 'appear/service'

module Appear
  class MacToolError < Error
    def initialize(message, stack)
      super("Mac error #{message.inspect}\n#{stack}")
    end
  end

  # The MacOs service handles macOS-specific concerns; mostly running our
  # companion macOS helper tool.
  class MacOs < Service
    delegate :run, :runner

    # the "realpath" part is basically an assertion that this file exists.
    SCRIPT = Appear::TOOLS_DIR.join('macOS-helper.js').realpath.to_s

    # call a method in our helper script. Communicates with JSON!
    def call_method(method_name, data = nil)
      command = [SCRIPT, method_name.to_s]
      command << data.to_json unless data.nil?
      output = run(command)
      result = JSON.load(output.lines.last.strip)

      if result["status"] == "error"
        raise MacToolError.new(result["error"]["message"], result["error"]["stack"])
      else
        result["value"]
      end
    end

    # TODO: ask Applescript if this a GUI application instead of just looking
    # at the path
    def has_gui?(process)
      executable = process.command.first
      executable =~ /\.app\/Contents\//
    end
  end
end
