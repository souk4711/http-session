class HTTP::Session
  class Client
    # Make an HTTP request without any HTTP::Features.
    #
    # @author [httprb/http](https://github.com/httprb/http/blob/main/lib/http/client.rb)
    module Perform
      HTTP_OR_HTTPS_RE = %r{^https?://}i

      attr_reader :default_options

      def httprb_initialize(default_options)
        @default_options = HTTP::Options.new(default_options)
        @connection = nil
        @state = :clean
      end

      def httprb_perform(req, options)
        verify_connection!(req.uri)

        @state = :dirty
        begin
          @connection ||= HTTP::Connection.new(req, options)
          unless @connection.failed_proxy_connect?
            @connection.send_request(req)
            @connection.read_headers!
          end
        rescue HTTP::Error => e
          options.features.each_value do |feature|
            feature.on_error(req, e)
          end
          raise
        end

        res = build_response(req, options)
        @connection.finish_response if req.verb == :head
        @state = :clean
        res
      rescue
        close
        raise
      end

      private

      def verify_connection!(uri)
        if default_options.persistent? && uri.origin != default_options.persistent
          raise HTTP::StateError, "Persistence is enabled for #{default_options.persistent}, but we got #{uri.origin}"
        end
        return close if @connection && (!@connection.keep_alive? || @connection.expired?)
        close if @state == :dirty
      end

      def close
        @connection&.close
        @connection = nil
        @state = :clean
      end

      def build_response(req, options)
        res = HTTP::Response.new(
          status: @connection.status_code,
          version: @connection.http_version,
          headers: @connection.headers,
          proxy_headers: @connection.proxy_response_headers,
          connection: @connection,
          encoding: options.encoding,
          request: req
        )
        HTTP::Session::Response.new(res)
      end

      def wrap_response(res, opts)
        opts.features.inject(res) do |response, (_name, feature)|
          response = feature.wrap_response(response)
          HTTP::Session::Response.new(response)
        end
      end

      def build_request(verb, uri, opts = {})
        opts = @default_options.merge(opts)
        uri = make_request_uri(uri, opts)
        headers = make_request_headers(opts)
        body = make_request_body(opts, headers)
        req = HTTP::Request.new(
          verb: verb,
          uri: uri,
          uri_normalizer: opts.feature(:normalize_uri)&.normalizer,
          proxy: opts.proxy,
          headers: headers,
          body: body
        )
        HTTP::Session::Request.new(req)
      end

      def wrap_request(req, opts)
        opts.features.inject(req) do |request, (_name, feature)|
          request = feature.wrap_request(request)
          HTTP::Session::Request.new(request)
        end
      end

      def make_request_uri(uri, opts)
        uri = uri.to_s
        uri = "#{default_options.persistent}#{uri}" if default_options.persistent? && uri !~ HTTP_OR_HTTPS_RE
        uri = HTTP::URI.parse uri
        uri.query_values = uri.query_values(Array).to_a.concat(opts.params.to_a) if opts.params && !opts.params.empty?
        uri.path = "/" if uri.path.empty?
        uri
      end

      def make_request_headers(opts)
        headers = opts.headers
        headers[HTTP::Headers::CONNECTION] = default_options.persistent? ? HTTP::Connection::KEEP_ALIVE : HTTP::Connection::CLOSE
        cookies = opts.cookies.values
        unless cookies.empty?
          cookies = opts.headers.get(HTTP::Headers::COOKIE).concat(cookies).join("; ")
          headers[HTTP::Headers::COOKIE] = cookies
        end
        headers
      end

      def make_request_body(opts, headers)
        if opts.body
          opts.body
        elsif opts.form
          form = make_form_data(opts.form)
          headers[HTTP::Headers::CONTENT_TYPE] ||= form.content_type
          form
        elsif opts.json
          body = HTTP::MimeType[:json].encode opts.json
          headers[HTTP::Headers::CONTENT_TYPE] ||= "application/json; charset=#{body.encoding.name.downcase}"
          body
        end
      end

      def make_form_data(form)
        return form if form.is_a? HTTP::FormData::Multipart
        return form if form.is_a? HTTP::FormData::Urlencoded
        HTTP::FormData.create(form)
      end
    end
  end
end
