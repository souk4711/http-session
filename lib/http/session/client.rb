class HTTP::Session
  class Client
    include HTTP::Session::Client::Perform

    # @param [Hash] default_options
    # @param [Session] session
    def initialize(default_options, session)
      httprb_initialize(default_options)
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
        request = HTTP::Session::Request.new(request)
        perform(request, opts)
      end.tap do |res|
        res.history = hist
      end
    end

    private

    # Make an HTTP request.
    #
    # @param [Request] req
    # @param [HTTP::Options] opts
    # @return [Response]
    def perform(req, opts)
      req = wrap_request(req, opts)
      wrap_response(_hs_perform(req, opts), opts)
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

    # Make an HTTP request using cache.
    def _hs_perform(req, opts)
      if @session.default_options.cache.enabled?
        req.cacheable? ? _hs_cache_lookup(req, opts) : _hs_cache_pass(req, opts)
      else
        _hs_forward(req, opts)
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
      res = _hs_forward(req, opts)
      _hs_cache_entry_store(req, res)

      res.headers[HTTP::Session::Cache::Status::HEADER_NAME] = HTTP::Session::Cache::Status::MISS
      res
    end

    # The cache entry is fresh, reuse it.
    def _hs_cache_reuse(req, opts, entry)
      res = entry.to_response(req)
      res.headers[HTTP::Headers::AGE] = [(res.now - res.date).to_i, 0].max.to_s
      res.headers[HTTP::Session::Cache::Status::HEADER_NAME] = HTTP::Session::Cache::Status::HIT
      res
    end

    # The cache entry is stale, revalidate it. The original request is used
    # as a template for a conditional GET request with the backend.
    def _hs_cache_validate(req, opts, entry)
      req.headers[HTTP::Headers::IF_MODIFIED_SINCE] = entry.response.last_modified if entry.response.last_modified
      req.headers[HTTP::Headers::IF_NONE_MATCH] = entry.response.etag if entry.response.etag

      res = _hs_forward(req, opts)
      if res.status.not_modified?
        res = entry.to_response(req)
        res.headers[HTTP::Session::Cache::Status::HEADER_NAME] = HTTP::Session::Cache::Status::REVALIDATED
        return res
      end

      _hs_cache_entry_store(req, res)
      res.headers[HTTP::Session::Cache::Status::HEADER_NAME] = HTTP::Session::Cache::Status::EXPIRED
      res
    end

    # The request is not cacheable. So the request is sent to the backend, and the
    # backend's response is sent to the client, but is not entered into the cache.
    def _hs_cache_pass(req, opts)
      res = _hs_forward(req, opts)
      res.headers[HTTP::Session::Cache::Status::HEADER_NAME] = HTTP::Session::Cache::Status::UNCACHEABLE
      res
    end

    # Store the response to cache.
    def _hs_cache_entry_store(req, res)
      if res.cacheable?(shared: @session.cache.shared?, req: req)
        @session.cache.write(req, res)
      end
    end

    # Delegate the request to the backend and create the response.
    def _hs_forward(req, opts)
      httprb_perform(req, opts)
    end
  end
end
