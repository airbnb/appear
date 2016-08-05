module Appear
  # join objects based on hash value or method value.
  #
  # example:
  #
  # ```
  # foos = many_foos
  # bars = many_bars
  # foo_bars = Join.join(:common_attribute, foos, bars)
  #
  # # can still access all the properties on either a foo or a bar
  # foo_bars.first.common_attribute
  #
  # # can access attributes by symbol, too
  # foo_bars.first[:something_else]
  # ```
  #
  # foo_bars is an array of Join instances. Reads from a foo_bar will read
  # first from the foo, and then from the bar - this is based on the order of
  # "tables" passed to Join.join().
  class Join
    # @param field [Symbol] the method or hash field name to join on.
    # @param tables [Array<Any>] arrays of any sort of object, so long as it is
    # either a hash, or implements the given field.
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

    def self.can_access?(obj, field)
      if obj.respond_to?(field)
        return true
      elsif obj.respond_to?(:[])
        return true
      end
      return false
    end

    def self.access(obj, field)
      if obj.respond_to?(field)
        obj.send(field)
      elsif obj.respond_to?(:[])
        obj[field]
      else
        raise "cannot access #{field.inspect} on #{object.inspect}"
      end
    end

    # an instance of Join is a joined object containing all the data in all its
    # parts. Joins are read from left to right, returning the first non-nil
    # value encountered.
    def initialize(*objs)
      @objs = objs
    end

    def push!(obj, note = nil)
      @objs << obj
    end

    def joined_count
      @objs.length
    end

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

    def method_missing(method, *args, &block)
      raise NoMethodError.new("Cannot access #{method.inspect}") unless respond_to?(method)
      raise ArgumentError.new("Passed args to accessor") if args.length > 0
      raise ArgumentError.new("Passed block to accessor") if block
      self[method]
    end

    def respond_to?(sym, priv = false)
      super(sym, priv) || (@objs.any? { |o| self.class.can_access?(o, sym) })
    end
  end
end
