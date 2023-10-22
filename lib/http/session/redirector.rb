class HTTP::Session
  # Mostly borrowed from [http/lib/http/redirector.rb](https://github.com/httprb/http/blob/main/lib/http/redirector.rb)
  class Redirector
    # HTTP status codes which indicate redirects
    REDIRECT_CODES = HTTP::Redirector::REDIRECT_CODES

    # Codes which which should raise StateError in strict mode if original
    # request was any of {UNSAFE_VERBS}
    STRICT_SENSITIVE_CODES = HTTP::Redirector::STRICT_SENSITIVE_CODES

    # Insecure http verbs, which should trigger StateError in strict mode
    # upon {STRICT_SENSITIVE_CODES}
    UNSAFE_VERBS = HTTP::Redirector::UNSAFE_VERBS

    # Verbs which will remain unchanged upon See Other response.
    SEE_OTHER_ALLOWED_VERBS = HTTP::Redirector::SEE_OTHER_ALLOWED_VERBS

    # @param [Hash] opts
    # @option opts [Boolean] :strict (true) redirector hops policy
    # @option opts [#to_i] :max_hops (5) maximum allowed amount of hops
    def initialize(opts = {})
      @strict = opts.fetch(:strict, true)
      @max_hops = opts.fetch(:max_hops, 5).to_i
      @on_redirect = opts.fetch(:on_redirect, nil)
    end

    def perform(response, &blk)
      request = response.request
      visited = []
      history = []

      while REDIRECT_CODES.include?(response.status.code)
        history << response
        visited << "#{request.verb} #{request.uri}"
        raise HTTP::Session::Exceptions::RedirectError, "too many hops" if too_many_hops?(visited)
        raise HTTP::Session::Exceptions::RedirectError, "endless loop" if endless_loop?(visited)

        location = response.headers.get(HTTP::Headers::LOCATION).inject(:+)
        raise HTTP::Session::Exceptions::RedirectError, "no Location header in redirect" unless location

        verb = make_redirect_to_verb(response, request)
        uri = make_redirect_to_uri(response, request, location)
        ctx = make_redirect_to_ctx(response, request, verb, uri)

        @on_redirect.call(response, request) if @on_redirect.respond_to?(:call)
        response = blk.call(verb, uri, ctx)
        request = response.request
      end

      response.history = history
      response
    end

    private

    def too_many_hops?(visited)
      @max_hops >= 1 && @max_hops < visited.count
    end

    def endless_loop?(visited)
      visited.count(visited.last) >= 2
    end

    def make_redirect_to_verb(response, request)
      verb = request.verb
      code = response.status.code

      if UNSAFE_VERBS.include?(verb) && STRICT_SENSITIVE_CODES.include?(code)
        raise HTTP::Session::Exceptions::RedirectError, "can't follow #{response.status} redirect" if @strict
        verb = :get
      end
      if !SEE_OTHER_ALLOWED_VERBS.include?(verb) && code == 303
        verb = :get
      end

      verb
    end

    def make_redirect_to_uri(response, request, location)
      request.uri.join(location)
    end

    def make_redirect_to_ctx(response, request, verb, uri)
      HTTP::Session::Context::FollowContext.new(
        request: request, verb: verb, uri: uri
      )
    end
  end
end
