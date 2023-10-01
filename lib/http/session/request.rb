class HTTP::Session
  # @author [rack/rack-cache](https://github.com/rack/rack-cache)
  # @author [souk4711/http-session](https://github.com/souk4711/http-session)
  class Request < SimpleDelegator
    class << self
      def new(*args)
        args[0].is_a?(self) ? args[0] : super
      end
    end

    # A CacheControl instance based on the request's cache-control header.
    #
    # @return [Cache::CacheControl]
    def cache_control
      @cache_control ||= HTTP::Session::Cache::CacheControl.new(headers[HTTP::Headers::CACHE_CONTROL])
    end

    # Determine if the request is worth caching under any circumstance.
    def cacheable?
      return false if verb != :get && verb != :head
      return false if cache_control.no_store?
      true
    end

    # True when the cache-control/no-cache directive is present.
    def no_cache?
      cache_control.no_cache?
    end
  end
end
