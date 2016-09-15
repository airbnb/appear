require 'appear/constants'

module Appear
  module Util

    # An immutable value type, similar to Struct, but with annotated
    # attr_readers, that can be easily created from a Hash with the necessary
    # fields.
    class ValueClass
      # Thrown if a value is not supplied for an attribute
      class MissingValueError < ::Appear::Error; end

      # @param data [Hash]
      def initialize(data)
        self.class.properties.each do |val|
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
      # @option opts [Symbol] :var instance variable we should read from
      #
      # @!macro [attach] value_class_property
      #   @!method $1
      #   The $1 property.
      def self.property(name, opts = {})
        var_name = opts.fetch(:var, name)

        @props ||= []
        @props << var_name

        # we could do super, but we want to allow defining :acttive? or so
        class_eval "def #{name}; @#{var_name}; end"

        var_name
      end

      # @return [Array<Symbol>] names of all properties
      def self.properties
        @props ||= []
        if self.superclass.respond_to?(:properties)
          self.superclass.properties + @props
        else
          @props
        end
      end
    end

  end
end
