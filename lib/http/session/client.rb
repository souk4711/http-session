class HTTP::Session
  class Client < HTTP::Client
    def request(verb, uri, opts, session)
      hist = []
      data = session.make_http_request_data

      opts = @default_options.merge(opts)
      opts = _hs_handle_http_request_options_cookies(opts, data)
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

    # Add session cookie to the request's :cookies.
    def _hs_handle_http_request_options_cookies(opts, data)
      session_cookies = data[:cookies]
      return opts if session_cookies.nil?

      opts.with_cookies(session_cookies)
    end

    # Wrap the :on_redirect method in the request's :follow.
    def _hs_handle_http_request_options_follow(opts, hist)
      return opts unless opts.follow

      follow = (opts.follow == true) ? {} : opts.follow
      opts.with_follow(follow.merge(
        on_redirect: _hs_handle_http_request_options_follow_hijack(follow[:on_redirect], hist)
      ))
    end

    def _hs_handle_http_request_options_follow_hijack(fn, hist)
      lambda do |res, req|
        hist << res
        fn.call(res, req) if fn.respond_to?(:call)
      end
    end

    def perform(*)
      HTTP::Session::Response.new(super)
    end

    def build_response(*)
      HTTP::Session::Response.new(super)
    end

    def build_request(*)
      HTTP::Session::Request.new(super)
    end

    def wrap_request(*)
      HTTP::Session::Request.new(super)
    end
  end
end
