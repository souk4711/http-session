class HTTP::Session
  class Options
    attr_reader :http

    def initialize(options = {})
      options = options.to_hash

      @http = HTTP::Options.new(
        options.slice(
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

    def merge(*args)
      tap { @http = @http.merge(*args) }
    end

    def with_cookies(*args)
      tap { @http = @http.with_cookies(*args) }
    end

    def with_encoding(*args)
      tap { @http = @http.with_encoding(*args) }
    end

    def with_features(*args)
      tap { @http = @http.with_features(*args) }
    end

    def with_follow(*args)
      tap { @http = @http.with_follow(*args) }
    end

    def with_headers(*args)
      tap { @http = @http.with_headers(*args) }
    end

    def with_nodelay(*args)
      tap { @http = @http.with_nodelay(*args) }
    end

    def with_proxy(*args)
      tap { @http = @http.with_proxy(*args) }
    end
  end
end
