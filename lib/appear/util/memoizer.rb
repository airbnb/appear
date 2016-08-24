require 'thread'
module Appear
  module Util
    # A Memoizer memoizes calls to a block, skipping repeated work when the
    # arguments are the same.
    class Memoizer
      def initialize
        @cache = {}
        @cache_mutex = Mutex.new
        @disable = false
      end

      # Memoize the call to a block. Any arguments given to this method will be
      # passed to the given block.
      def call(*args)
        if @disable
          return yield(*args)
        end

        raise ArgumentError.new('no block given') unless block_given?
        @cache_mutex.synchronize do
          return @cache[args] if @cache.key?(args)
        end

        result = yield(*args)
        @cache_mutex.synchronize do
          @cache[args] = result
        end
        result
      end

      # Evict the cache
      # @return [self]
      def clear!
        @cache_mutex.synchronize do
          @cache = {}
        end
        self
      end

      # Disable memoization permanently on this instance.
      # @return [self]
      def disable!
        @disable = true
        self
      end
    end
  end
end