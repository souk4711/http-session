class HTTP::Session
  class Options
    class CacheOption
      # @!attribute [r] store
      #   @return [ActiveSupport::Cache::Store]
      attr_reader :store

      # @param [Hash] options
      # @option options [Boolean] :private set true if it is a private cache
      # @option options [Boolean] :shared set true if it is a shared cache
      # @option options [ActiveSupport::Cache::Store] :store
      def initialize(options)
        options =
          case options
          when nil, false then {enabled: false}
          when true then {enabled: true}
          else options
          end

        # Enabled / Disabled
        @enabled = options.fetch(:enabled, true)

        # Shared Cache / Private Cache
        @shared =
          if options.key?(:shared)
            raise ArgumentError, ":shared and :private cannot be used at the same time" if options.key?(:private)
            !!options[:shared]
          elsif options.key?(:private)
            !options[:private]
          else
            true
          end

        # Cache Store
        @store =
          if options.key?(:store)
            options[:store]
          elsif @enabled
            require "active_support/cache"
            require "active_support/notifications"
            ActiveSupport::Cache::MemoryStore.new
          end
      end

      # Indicates whether or not the session cache feature is enabled.
      def enabled?
        @enabled
      end

      # True when it is a shared cache.
      #
      # Shared Cache that exists between the origin server and clients (e.g. Proxy, CDN).
      # It stores a single response and reuses it with multiple users
      def shared_cache?
        @shared
      end

      # True when it is a private cache.
      #
      # Private Cache that exists in the client. It is also called local cache or browser cache.
      # It can store and reuse personalized content for a single user.
      def private_cache?
        !shared_cache?
      end
    end
  end
end
