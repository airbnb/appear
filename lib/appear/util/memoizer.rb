require 'thread'

module Appear
  module Util
    # A Memoizer memoizes calls to a block, skipping repeated work when the
    # arguments are the same. Memoization is thread-safe, so it's safe to
    # memoize pure computations that occur on different threads.
    #
    # @example memoize a method
    #   class Example
    #     def initialize
    #       @memo = Memoizer.new
    #     end
    #
    #     def foo(a, b)
    #       @memo.call(a, b) do
    #         expensive_computaion(a, b)
    #       end
    #     end
    #   end
    #
    # @example memoize part of a computation
    #   class Example
    #     def initialize
    #       @memo = Memoizer.new
    #     end
    #
    #     def foo(a, b)
    #       state = get_state(a, b)
    #       d = memo.call(state) { expensive_pure_computation(state) }
    #       [a, d]
    #     end
    #   end
    class Memoizer
      def initialize
        @cache = {}
        @cache_mutex = Mutex.new
        @disable = false
      end

      # Memoize the call to a block. Any arguments given to this method will be
      # passed to the given block.
      #
      # @param args [Array<Any>] memoization key
      # @return [Any] result of the block
      def call(*args)
        raise ArgumentError.new('no block given') unless block_given?

        if @disable
          return yield
        end

        @cache_mutex.synchronize do
          return @cache[args] if @cache.key?(args)
        end

        result = yield
        @cache_mutex.synchronize do
          @cache[args] = result
        end
        result
      end

      # Evict the cache
      #
      # @return [self]
      def clear!
        @cache_mutex.synchronize do
          @cache = {}
        end
        self
      end

      # Disable memoization permanently on this instance.
      #
      # @return [self]
      def disable!
        @disable = true
        self
      end
    end
  end
end
