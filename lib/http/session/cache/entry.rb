class HTTP::Session
  class Cache
    class Entry
      class << self
        # Deserializes from a JSON primitive type.
        def deserialize(hash)
          req = HTTP::Request.new(hash[:req])
          req = HTTP::Session::Request.new(req)
          res = HTTP::Response.new(hash[:res].merge(request: req))
          res = HTTP::Session::Response.new(res)
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
        res = HTTP::Response.new(h.merge(request: req))
        res = HTTP::Session::Response.new(res)
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
