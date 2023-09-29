class HTTP::Session
  # Provides the same configure API interfaces as HTTP::Client.
  #
  # @see https://github.com/httprb/http/blob/main/lib/http/chainable.rb
  module Configurable
    # Set timeout on request.
    #
    # @overload timeout(options = {})
    #   Adds per operation timeouts to the request.
    #   @param [Hash] options
    #   @option options [Float] :read Read timeout
    #   @option options [Float] :write Write timeout
    #   @option options [Float] :connect Connect timeout
    #   @return [Session]
    #
    # @overload timeout(global_timeout)
    #   Adds a global timeout to the full request.
    #   @param [Numeric] global_timeout
    #   @return [Session]
    def timeout(options)
      klass, options =
        case options
        when Numeric then [HTTP::Timeout::Global, {global: options}]
        when Hash then [HTTP::Timeout::PerOperation, options.dup]
        when :null then [HTTP::Timeout::Null, {}]
        else raise ArgumentError, "Use `.timeout(global_timeout_in_seconds)` or `.timeout(connect: x, write: y, read: z)`."
        end

      %i[global read write connect].each do |k|
        next unless options.key? k
        options["#{k}_timeout".to_sym] = options.delete k
      end

      branch default_options.merge(
        timeout_class: klass,
        timeout_options: options
      )
    end

    # Make a request through an HTTP proxy.
    #
    # @param [Array] proxy
    # @return [Session]
    def via(*proxy)
      proxy_hash = {}
      proxy_hash[:proxy_address] = proxy[0] if proxy[0].is_a?(String)
      proxy_hash[:proxy_port] = proxy[1] if proxy[1].is_a?(Integer)
      proxy_hash[:proxy_username] = proxy[2] if proxy[2].is_a?(String)
      proxy_hash[:proxy_password] = proxy[3] if proxy[3].is_a?(String)
      proxy_hash[:proxy_headers] = proxy[2] if proxy[2].is_a?(Hash)
      proxy_hash[:proxy_headers] = proxy[4] if proxy[4].is_a?(Hash)
      raise ArgumentError, "invalid HTTP proxy: #{proxy_hash}" unless (2..5).cover?(proxy_hash.keys.size)

      branch default_options.with_proxy(proxy_hash)
    end
    alias_method :through, :via

    # Make client follow redirects.
    #
    # @param options
    # @return [Session]
    def follow(options = {})
      branch default_options.with_follow options
    end

    # Make a request with the given headers.
    #
    # @param headers
    # @return [Session]
    def headers(headers)
      branch default_options.with_headers(headers)
    end

    # Make a request with the given cookies.
    #
    # @param cookies
    # @return [Session]
    def cookies(cookies)
      branch default_options.with_cookies(cookies)
    end

    # Force a specific encoding for response body.
    #
    # @param encoding
    # @return [Session]
    def encoding(encoding)
      branch default_options.with_encoding(encoding)
    end

    # Accept the given MIME type(s).
    #
    # @param type
    # @return [Session]
    def accept(type)
      headers HTTP::Headers::ACCEPT => HTTP::MimeType.normalize(type)
    end

    # Make a request with the given Authorization header.
    #
    # @param [#to_s] value Authorization header value
    # @return [Session]
    def auth(value)
      headers HTTP::Headers::AUTHORIZATION => value.to_s
    end

    # Make a request with the given Basic authorization header.
    #
    # @see http://tools.ietf.org/html/rfc2617
    # @param [#fetch] opts
    # @option opts [#to_s] :user
    # @option opts [#to_s] :pass
    # @return [Session]
    def basic_auth(opts)
      user = opts.fetch(:user)
      pass = opts.fetch(:pass)
      creds = "#{user}:#{pass}"

      auth("Basic #{Base64.strict_encode64(creds)}")
    end

    # Set TCP_NODELAY on the socket.
    #
    # @return [Session]
    def nodelay
      branch default_options.with_nodelay(true)
    end

    # Turn on given features.
    #
    # @return [Session]
    def use(*features)
      branch default_options.with_features(features)
    end

    private

    # :nodoc:
    def default_options
      @options
    end

    # :nodoc:
    def branch(options)
      tap { @options = options }
    end
  end
end
