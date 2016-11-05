require 'json'

require 'appear/constants'
require 'appear/service'

module Appear
  # Raised if our helper program returns an error.
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
    # @param method_name [String, Symbol] check the source of macOS-helper.js for method names.
    # @param data [Any, nil] json-able data to pass to the named method.
    # @return [Any] json data returned from the helper
    # @raise [MacToolError] if an error occurred
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

    # Return true if the given process is a macOS GUI process, false otherwise.
    #
    # @todo: ask Applescript if this a GUI application instead of just looking
    #   at the path
    #
    # @param process [Appear::Processes::ProcessInfo]
    # @return [Boolean]
    def has_gui?(process)
      executable = process.command.first
      executable =~ /\.app\/Contents\//
    end
  end
end
