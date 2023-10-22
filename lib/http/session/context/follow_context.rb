class HTTP::Session
  class Context
    class FollowContext
      def initialize(opts)
        @request = opts[:request]
        @verb = opts[:verb]
        @uri = opts[:uri]
      end

      def same_origin?
        @request.uri.origin == @uri.origin
      end

      def cross_origin?
        !same_origin?
      end
    end
  end
end
