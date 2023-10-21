class HTTP::Session
  class Options
    class CacheOption
      include Optionable

      # @!attribute [r] store
      #   @return [ActiveSupport::Cache::Store]
      attr_reader :store

      # @param [Hash] opts
      # @option opts [Boolean] :private set true if it is a private cache
      # @option opts [Boolean] :shared set true if it is a shared cache
      # @option opts [ActiveSupport::Cache::Store] :store
      def initialize(opts)
        initialize_options(opts)

        # Shared Cache / Private Cache
        @shared =
          if @options.key?(:shared)
            raise ArgumentError, ":shared and :private cannot be used at the same time" if @options.key?(:private)
            !!@options[:shared]
          elsif @options.key?(:private)
            !@options[:private]
          else
            true
          end

        # Cache Store
        @store =
          if enabled?
            store = @options[:store]
            if store.respond_to?(:read) && store.respond_to?(:write)
              store
            else
              lookup_store(store)
            end
          end
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

      # @!visibility private
      def freeze
        super
      end

      private

      def lookup_store(store)
        load_dependencies
        ActiveSupport::Cache.lookup_store(store)
      end

      def load_dependencies
        require "active_support/cache"
        require "active_support/notifications"
      rescue LoadError
        raise LoadError,
          "Specified 'active_support' for caching, but the gem is not loaded. Add `gem 'active_support'` to your Gemfile."
      end
    end
  end
end
