class HTTP::Session
  class Cache
    def initialize(session)
      @session = session
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
      @session.default_options.cache.private_cache?
    end

    # True when it is a shared cache.
    def shared?
      @session.default_options.cache.shared_cache?
    end

    private

    def store
      @session.default_options.cache.store
    end
  end
end
