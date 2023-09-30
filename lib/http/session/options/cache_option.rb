class HTTP::Session
  class Options
    class CacheOption
      # @param [Hash] options
      def initialize(options)
        options =
          case options
          when nil, false then {enabled: false}
          when true then {enabled: true}
          else options
          end

        # Enabled/Disabled
        @enabled = options.fetch(:enabled, true)

        # Private Cache/Shared Cache
        @private =
          if options.key?(:private)
            raise ArgumentError, ":private and :shared cannot be used at the same time" if options.key?(:shared)
            !!options[:private]
          elsif options.key?(:shared)
            !options[:shared]
          else
            false
          end
      end

      # Indicates whether or not the session cache feature is enabled.
      def enabled?
        @enabled
      end

      # True when it is a private cache.
      #
      # Private Cache that exists in the client. It is also called local cache or browser cache.
      # It can store and reuse personalized content for a single user.
      def private_cache?
        @private
      end

      # True when it is a shared cache.
      #
      # Shared Cache that exists between the origin server and clients (e.g. Proxy, CDN).
      # It stores a single response and reuses it with multiple users
      def shared_cache?
        !@private
      end
    end
  end
end
