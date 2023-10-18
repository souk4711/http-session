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
          @options.fetch(:pools, {"*" => true})
      end
    end
  end
end
