class HTTP::Session
  class Cache
    class Entry
      def fresh?
        false
      end

      # @param [Request] req
      # @return [Response]
      def to_response(req)
      end
    end
  end
end
