module Appear
  module Util
    # An immutable value type, similar to Struct, but with annotated
    # attr_readers, that can be easily created from a Hash with the necessary
    # fields.
    class ValueClass
      # @param data [Hash]
      def initialize(data)
        self.class.values.each do |val|
          instance_variable_set("@#{val}", data.fetch(val))
        end
      end

      # Define an attribute reader that can be populated by the constructor.
      #
      # @param name [Symbol] define an attr_reader with this name
      # @param var_name [Symbol] read from this instance variable, or the name
      def self.attr_reader(name, var_name = nil)
        var_name ||= name

        @values ||= []
        @values << var_name

        class_eval "def #{name}; @#{var_name}; end"
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
