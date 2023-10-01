class HTTP::Session
  class Cache
    # @param [Options::CacheOption] options
    def initialize(options)
      @options = options
    end

    # @param [Request] req
    # @param [Response] res
    def write(req, res)
    end

    # @param [Request] req
    # @return [Entry]
    def read(req)
    end

    # True when it is a private cache.
    def private?
      @options.private_cache?
    end

    # True when it is a shared cache.
    def shared?
      @options.shared_cache?
    end

    private

    def store
      @options.store
    end
  end
end
