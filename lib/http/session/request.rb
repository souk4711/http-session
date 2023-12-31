class HTTP::Session
  # Provides access to the HTTP request.
  #
  # Mostly borrowed from [rack-cache/lib/rack/cache/request.rb](https://github.com/rack/rack-cache/blob/main/lib/rack/cache/request.rb)
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

    # True when the cache-control/no-cache directive is present.
    def no_cache?
      cache_control.no_cache?
    end

    # Determine if the request is worth caching under any circumstance.
    def cacheable?
      return false if verb != :get && verb != :head
      return false if cache_control.no_store?
      true
    end
  end
end
