# See https://github.com/httprb/http/blob/main/lib/http/chainable.rb

class HTTP::Session
  module Requestable
    # Request a get sans response body.
    #
    # @param uri
    # @option options [Hash]
    def head(uri, options = {})
      request :head, uri, options
    end

    # Get a resource.
    #
    # @param uri
    # @option options [Hash]
    def get(uri, options = {})
      request :get, uri, options
    end

    # Post to a resource.
    #
    # @param uri
    # @option options [Hash]
    def post(uri, options = {})
      request :post, uri, options
    end

    # Put to a resource.
    #
    # @param uri
    # @option options [Hash]
    def put(uri, options = {})
      request :put, uri, options
    end

    # Delete a resource.
    #
    # @param uri
    # @option options [Hash]
    def delete(uri, options = {})
      request :delete, uri, options
    end

    # Echo the request back to the client.
    #
    # @param uri
    # @option options [Hash]
    def trace(uri, options = {})
      request :trace, uri, options
    end

    # Return the methods supported on the given URI.
    #
    # @param uri
    # @option options [Hash]
    def options(uri, options = {})
      request :options, uri, options
    end

    # Convert to a transparent TCP/IP tunnel.
    #
    # @param uri
    # @option options [Hash]
    def connect(uri, options = {})
      request :connect, uri, options
    end

    # Apply partial modifications to a resource.
    #
    # @param uri
    # @option options [Hash]
    def patch(uri, options = {})
      request :patch, uri, options
    end
  end
end
