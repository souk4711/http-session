class HTTP::Session
  class Client
    include HTTP::Session::Client::Perform

    # @param [Hash] default_options
    # @param [Session] session
    def initialize(default_options, session)
      httprb_initialize(default_options)
      @session = session
    end

    # Make an HTTP request.
    #
    # @param verb
    # @param uri
    # @param [Hash] opts
    # @return [Response]
    def request(verb, uri, opts)
      opts = default_options.merge(opts)
      opts = _hs_handle_http_request_options_cookies(opts)

      req = build_request(verb, uri, opts)
      res = perform(req, opts)
      _hs_cookies_save(res)

      res
    end

    private

    # Add session cookies to the request's :cookies.
    def _hs_handle_http_request_options_cookies(opts)
      cookies = _hs_cookies_load
      cookies.nil? ? opts : opts.with_cookies(cookies)
    end

    # Load cookies.
    def _hs_cookies_load
      return unless @session.cookies_mgr.enabled?
      @session.cookies_mgr.read
    end

    # Save cookies.
    def _hs_cookies_save(res)
      return unless @session.cookies_mgr.enabled?
      @session.cookies_mgr.write(res)
    end

    # Perform a single HTTP request with features.
    #
    # @param [Request] req
    # @param [HTTP::Options] opts
    # @return [Response]
    def perform(req, opts)
      req = wrap_request(req, opts)
      wrap_response(_hs_perform(req, opts), opts)
    end

    # Perform a single HTTP request.
    def _hs_perform(req, opts)
      if @session.cache_mgr.enabled?
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
      entry = @session.cache_mgr.read(req)
      if entry.nil?
        _hs_cache_fetch(req, opts)
      elsif entry.response.fresh?(shared: @session.cache_mgr.shared_cache?) &&
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
      if res.cacheable?(shared: @session.cache_mgr.shared_cache?, req: req)
        @session.cache_mgr.write(req, res)
      end
    end

    # Delegate the request to the backend and create the response.
    def _hs_forward(req, opts)
      res = httprb_perform(req, opts)
      res.flush if default_options.persistent?
      res
    end
  end
end
