class HTTP::Session
  class Client < HTTP::Client
    # @param [Hash] default_options
    # @param [Session] session
    def initialize(default_options, session)
      super(default_options)

      @session = session
    end

    # @param verb
    # @param uri
    # @param [Hash] opts
    # @return [Response]
    def request(verb, uri, opts)
      data = @session.make_http_request_data
      hist = []

      opts = @default_options.merge(opts)
      opts = _hs_handle_http_request_options_cookies(opts, data[:cookies])
      opts = _hs_handle_http_request_options_follow(opts, hist)

      req = build_request(verb, uri, opts)
      res = perform(req, opts)
      return res unless opts.follow

      HTTP::Redirector.new(opts.follow).perform(req, res) do |request|
        perform(wrap_request(request, opts), opts)
      end.tap do |res|
        res.history = hist
      end
    end

    private

    # @param [Request] req
    # @param [HTTP::Options] opts
    # @return [Response]
    def perform(req, opts)
      if @session.default_options.cache.enabled?
        req.cacheable? ? _hs_cache_lookup(req, opts) : _hs_cache_pass(req, opts)
      else
        _hs_perform(req, opts)
      end
    end

    # @return [Response]
    def build_response(*)
      HTTP::Session::Response.new(super)
    end

    # @return [Request]
    def build_request(*)
      HTTP::Session::Request.new(super)
    end

    # @return [Request]
    def wrap_request(*)
      HTTP::Session::Request.new(super)
    end

    # Add session cookie to the request's :cookies.
    def _hs_handle_http_request_options_cookies(opts, cookies)
      return opts if cookies.nil?
      opts.with_cookies(cookies)
    end

    # Wrap the :on_redirect method in the request's :follow.
    def _hs_handle_http_request_options_follow(opts, hist)
      return opts unless opts.follow

      follow = (opts.follow == true) ? {} : opts.follow
      opts.with_follow(follow.merge(
        on_redirect: _hs_handle_http_request_options_follow_hijack(follow[:on_redirect], hist)
      ))
    end

    # Wrap the :on_redirect method.
    def _hs_handle_http_request_options_follow_hijack(fn, hist)
      lambda do |res, req|
        hist << res
        fn.call(res, req) if fn.respond_to?(:call)
      end
    end

    # Try to serve the response from cache.
    #
    #   * When a matching cache entry is found and is fresh, use it as the response
    #     without forwarding any request to the backend.
    #   * When a matching cache entry is found but is stale, attempt to validate the
    #     entry with the backend using conditional GET.
    #   * When no matching cache entry is found, trigger miss processing.
    def _hs_cache_lookup(req, opts)
      entry = @session.cache.read(req)
      if entry.nil?
        _hs_cache_fetch(req, opts)
      elsif entry.response.fresh?(shared: @session.cache.shared?) &&
          !entry.response.no_cache? &&
          !req.no_cache?
        _hs_cache_reuse(req, opts, entry)
      else
        _hs_cache_validate(req, opts, entry)
      end
    end

    # The cache entry is missing. Forward the request to the backend and determine
    # whether the response should be stored.
    def _hs_cache_fetch(req, opts)
      res = _hs_perform(req, opts)

      _hs_cache_entry_store(req, res)
      res
    end

    # The cache entry is fresh, reuse it.
    def _hs_cache_reuse(req, opts, entry)
      entry.to_response(req)
    end

    # The cache entry is stale, revalidate it. The original request is used
    # as a template for a conditional GET request with the backend.
    def _hs_cache_validate(req, opts, entry)
      req.headers[HTTP::Headers::IF_MODIFIED_SINCE] = entry.response.last_modified if entry.response.last_modified
      req.headers[HTTP::Headers::IF_NONE_MATCH] = entry.response.etag if entry.response.etag

      res = _hs_perform(req, opts)
      return entry.to_response(req) if res.status.not_modified?

      _hs_cache_entry_store(req, res)
      res
    end

    # The request is not cacheable. So the request is sent to the backend, and the
    # backend's response is sent to the client, but is not entered into the cache.
    def _hs_cache_pass(req, opts)
      _hs_perform(req, opts)
    end

    # Store the response to cache.
    def _hs_cache_entry_store(req, res)
      if res.cacheable?(shared: @session.cache.shared?)
        @session.cache.write(req, res)
      end
    end

    # Delegate the request to the backend and create the response.
    def _hs_perform(req, opts)
      HTTP::Session::Response.new(method(:perform).super_method.call(req, opts))
    end
  end
end
