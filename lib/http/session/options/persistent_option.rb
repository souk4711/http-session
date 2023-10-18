class HTTP::Session
  class Options
    class PersistentOption
      include Optionable

      # @!attribute [r] pools
      #   @return [Hash]
      attr_reader :pools

      # @param [Hash] opts
      # @option opts [Hash] :pools parameters used to create ConnectionPool
      def initialize(opts)
        initialize_options(opts)

        @pools =
          normalize_pools(@options.fetch(:pools, {"*" => true}))
      end

      private

      def normalize_pools(pools)
        pools.transform_keys do |k|
          (k == "*") ? k : HTTP::URI.parse(k).origin
        end
      end
    end
  end
end
