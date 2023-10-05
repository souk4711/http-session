class HTTP::Session
  class Options
    # @!attribute [r] cookies
    #   @return [CookiesOption]
    attr_reader :cookies

    # @!attribute [r] cache
    #   @return [CacheOption]
    attr_reader :cache

    # @!attribute [r] http
    #   @return [HTTP::Options]
    attr_reader :http

    # @param [Hash] options
    def initialize(options)
      @cookies = HTTP::Session::Options::CookiesOption.new(options.fetch(:cookies, false))
      @cache = HTTP::Session::Options::CacheOption.new(options.fetch(:cache, false))
      @http = HTTP::Options.new(
        options.fetch(:http, {}).slice(
          :cookies,
          :encoding,
          :features,
          :follow,
          :headers,
          :keep_alive_timeout,
          :nodelay,
          :proxy,
          :response,
          :ssl,
          :ssl_socket_class,
          :socket_class,
          :timeout_class,
          :timeout_options
        )
      )
    end

    # @return [Options]
    def merge(other)
      tap { @http = @http.merge(other) }
    end

    # @return [Options]
    def with_cookies(cookies)
      tap { @http = @http.with_cookies(cookies) }
    end

    # @return [Options]
    def with_encoding(encoding)
      tap { @http = @http.with_encoding(encoding) }
    end

    # @return [Options]
    def with_features(features)
      raise ArgumentError, "feature :auto_inflate is not supported, use :hsf_auto_inflate instead" if features.include?(:auto_inflate)
      tap { @http = @http.with_features(features) }
    end

    # @return [Options]
    def with_follow(follow)
      tap { @http = @http.with_follow(follow) }
    end

    # @return [Options]
    def with_headers(headers)
      tap { @http = @http.with_headers(headers) }
    end

    # @return [Options]
    def with_nodelay(nodelay)
      tap { @http = @http.with_nodelay(nodelay) }
    end

    # @return [Options]
    def with_proxy(proxy)
      tap { @http = @http.with_proxy(proxy) }
    end
  end
end
