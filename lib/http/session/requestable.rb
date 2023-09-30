class HTTP::Session
  # Provides the same request API interfaces as HTTP::Client.
  #
  # @see https://github.com/httprb/http/blob/main/lib/http/chainable.rb
  module Requestable
    # Request a get sans response body.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def head(uri, options = {})
      request :head, uri, options
    end

    # Get a resource.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def get(uri, options = {})
      request :get, uri, options
    end

    # Post to a resource.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def post(uri, options = {})
      request :post, uri, options
    end

    # Put to a resource.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def put(uri, options = {})
      request :put, uri, options
    end

    # Delete a resource.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def delete(uri, options = {})
      request :delete, uri, options
    end

    # Echo the request back to the client.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def trace(uri, options = {})
      request :trace, uri, options
    end

    # Return the methods supported on the given URI.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def options(uri, options = {})
      request :options, uri, options
    end

    # Convert to a transparent TCP/IP tunnel.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def connect(uri, options = {})
      request :connect, uri, options
    end

    # Apply partial modifications to a resource.
    #
    # @param uri
    # @option [Hash] options
    # @return [Response]
    def patch(uri, options = {})
      request :patch, uri, options
    end
  end
end
