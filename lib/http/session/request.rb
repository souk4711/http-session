class HTTP::Session
  # @author [rack/rack-cache](https://github.com/rack/rack-cache)
  # @author [souk4711/http-session](https://github.com/souk4711/http-session)
  class Request < SimpleDelegator
    # A CacheControl instance based on the request's cache-control header.
    #
    # @return [Cache::CacheControl]
    def cache_control
      @cache_control ||= HTTP::Session::Cache::CacheControl.new(headers[HTTP::Headers::CACHE_CONTROL])
    end

    # True when the cache-control/no-cache directive is present.
    def no_cache?
      cache_control.no_cache?
    end
  end
end
