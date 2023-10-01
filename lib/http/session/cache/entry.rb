class HTTP::Session
  class Cache
    class Entry
      def fresh?
        false
      end

      def last_modified
        nil
      end

      def etag
        nil
      end

      # @param [Request] req
      # @return [Response]
      def to_response(req)
        HTTP::Session::Response.new
      end
    end
  end
end
