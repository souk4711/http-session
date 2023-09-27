class HTTP::Session
  class Options
    extend Forwardable

    class << self
      def new(options = {})
        options.is_a?(self) ? options : super
      end
    end

    attr_reader :http

    def_delegators :http,
      :with_cookies,
      :with_encoding,
      :with_features,
      :with_follow,
      :with_headers,
      :with_nodelay,
      :with_proxy

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
  end
end
