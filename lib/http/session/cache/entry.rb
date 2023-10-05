class HTTP::Session
  class Cache
    class Entry
      class << self
        # Deserializes from a JSON primitive type.
        def deserialize(h)
          req = h[:req]
          req = HTTP::Session::Request.new(HTTP::Request.new(req))

          res = h[:res]
          res[:request] = req
          res[:body] = HTTP::Session::Response::CachedBody.new(res[:body])
          res = HTTP::Session::Response.new(HTTP::Response.new(res))

          new(req, res)
        end
      end

      # @!attribute [r] request
      #   @return [Request]
      attr_reader :request

      # @!attribute [r] response
      #   @return [Response]
      attr_reader :response

      # Returns a new instance of Entry.
      def initialize(req, res)
        @request = req
        @response = res
      end

      # @param [Request] req                                                 │
      # @return [Response]
      def to_response(req)
        h = serialize_response
        h[:request] = req
        h[:body] = HTTP::Session::Response::CachedBody.new(h[:body])

        res = HTTP::Session::Response.new(HTTP::Response.new(h))
        res.from_cache = true
        res
      end

      # Serializes to a JSON primitive type.
      def serialize
        {
          req: serialize_request,
          res: serialize_response
        }
      end

      private

      def serialize_request
        {
          verb: @request.verb,
          uri: @request.uri.to_s,
          headers: @request.headers.to_h
        }
      end

      def serialize_response
        {
          status: @response.status.code,
          version: @response.version,
          headers: @response.headers.to_h,
          proxy_headers: @response.proxy_headers.to_h,
          body: @response.body.to_s
        }
      end
    end
  end
end
