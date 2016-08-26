require 'appear/constants'

module Appear
  module Util
    # Thrown if a value is not supplied for an attribute
    class MissingValueError < ::Appear::Error; end

    # An immutable value type, similar to Struct, but with annotated
    # attr_readers, that can be easily created from a Hash with the necessary
    # fields.
    class ValueClass
      # @param data [Hash]
      def initialize(data)
        self.class.values.each do |val|
          begin
            instance_variable_set("@#{val}", data.fetch(val))
          rescue KeyError
            raise MissingValueError.new("#{self.class.name}: no value for attribute #{val.inspect}")
          end
        end
      end

      # Define an attribute reader that can be populated by the constructor.
      #
      # @param name [Symbol] define an attr_reader with this name
      # @param opts [Hash] options
      # @opt opts [Symbol] :var instance variable we should read from
      def self.attr_reader(name, opts = {})
        var_name = opts.fetch(:var, name)

        @values ||= []
        @values << var_name

        # we could do super, but we want to allow defining :acttive? or so
        class_eval "def #{name}; @#{var_name}; end"

        var_name
      end

      # @return [Array<Symbol>] names of all values
      def self.values
        @values ||= []
        if self.superclass.respond_to?(:values)
          @values + self.superclass.values
        else
          @values
        end
      end
    end

  end
end
