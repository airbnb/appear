module Appear
  module Util
    # Class for joining objects based on hash value or method value.
    # @see Join.join
    class Join
      # Join objects or hashes together where thier field values match. This
      # method is analogous to a JOIN in SQL, although the behavior is not
      # exactly the same.
      #
      # @example
      #   foos = many_foos
      #   bars = many_bars
      #   foo_bars = Join.join(:common_attribute, foos, bars)
      #
      #   # can still access all the properties on either a foo or a bar
      #   foo_bars.first.common_attribute
      #
      #   # can access attributes by symbol, too
      #   foo_bars.first[:something_else]
      #
      # foo_bars is an array of Join instances. Reads from a foo_bar will read
      # first from the foo, and then from the bar - this is based on the order of
      # "tables" passed to Join.join().
      #
      # @param field [Symbol] the method or hash field name to join on.
      # @param tables [Array<Any>] arrays of any sort of object, so long as it is
      #   either a hash, or has a method named `field`.
      # @return [Array<Join>]
      def self.join(field, *tables)
        by_field = Hash.new { |h, k| h[k] = self.new }

        tables.each do |table|
          table.each do |row|
            field_value = access(row, field)
            joined = by_field[field_value]
            joined.push!(row)
          end
        end

        by_field.values.select do |joined|
          joined.joined_count >= tables.length
        end
      end

      # True if we can access the given field on an object, either by calling
      # that method on the object, or by accessing using []
      #
      # @param obj [Any]
      # @param field [Symbol, String]
      # @return [Boolean]
      def self.can_access?(obj, field)
        if obj.respond_to?(field)
          return true
        elsif obj.respond_to?(:[])
          return true
        end
        return false
      end

      # Access the given field on an object.
      # Raises an error if the field cannot be accessed.
      #
      # @param obj [Any]
      # @param field [Symbol, String]
      # @return [Any] the value at that field
      def self.access(obj, field)
        if obj.respond_to?(field)
          obj.send(field)
        elsif obj.respond_to?(:[])
          obj[field]
        else
          raise "cannot access #{field.inspect} on #{obj.inspect}"
        end
      end

      # A Join is a union of data objects. You can use a Join to group objects of
      # different types, so that you may read from whichever has a given field.
      #
      # It is more useful to use self.join to perform a join operation on
      # collections than to create Join objects directly.
      def initialize(*objs)
        @objs = objs
      end

      # add another data object to this join.
      #
      # @param obj [Any]
      def push!(obj)
        @objs << obj
      end

      # get the number of objects in this join
      #
      # @return [Fixnum]
      def joined_count
        @objs.length
      end

      # Return the first member in the join that matches the given block.
      # @yield [Object] join member.
      def unjoin(&block)
        @objs.find(&block)
      end

      # read a field from the join. Returns the first non-nil value we can read.
      # @see self.access for information about how fields are accessed.
      #
      # @param sym [String, Symbol] the field name
      # @return [Any, nil]
      def [](sym)
        result = nil

        @objs.each do |obj|
          if self.class.can_access?(obj, sym)
            result = self.class.access(obj, sym)
          end
          break unless result.nil?
        end

        result
      end

      # the {#method_missing} implementation on a Join allows you to access valid
      # fields with regular accessors.
      #
      # @param method [String, Symbol]
      # @param args [Array<Any>] should have none
      # @param block [Proc] should have none
      def method_missing(method, *args, &block)
        raise NoMethodError.new("Cannot access #{method.inspect}") unless respond_to?(method)
        raise ArgumentError.new("Passed args to accessor") if args.length > 0
        raise ArgumentError.new("Passed block to accessor") if block
        self[method]
      end

      # @param sym [String, Symbol] name of the method
      # @param priv [Boolean] default false
      # @return [Boolean] true if we can respond to the given method name
      def respond_to?(sym, priv = false)
        super(sym, priv) || (@objs.any? { |o| self.class.can_access?(o, sym) })
      end
    end
  end
end
