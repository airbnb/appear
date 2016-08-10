require 'thread'
module Appear
  # A Memoizer memoizes calls to a block, skipping repeated work when the
  # arguments are the same.
  class Memoizer
    def initialize
      @cache = {}
      @cache_mutex = Mutex.new
    end

    # Memoize the call to a block. Any arguments given to this method will be
    # passed to the given block.
    def call(*args)
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
    def clear!
      @cache_mutex.synchronize do
        @cache = {}
      end
      nil
    end
  end
end
