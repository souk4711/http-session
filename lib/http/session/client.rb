class HTTP::Session
  class Client < HTTP::Client
    def request(verb, uri, opts, session)
      opts = @default_options.merge(opts)
      req = build_request(verb, uri, opts)
      res = perform(req, opts)
      return res unless opts.follow

      HTTP::Redirector.new(opts.follow).perform(req, res) do |request|
        perform(wrap_request(request, opts), opts)
      end
    end

    private

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
