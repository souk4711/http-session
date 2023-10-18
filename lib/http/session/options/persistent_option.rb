class HTTP::Session
  class Options
    class PersistentOption
      include Optionable

      # @!attribute [r] connection
      #   @return [Hash]
      attr_reader :connection

      # @param [Hash] opts
      # @option opts [Hash] :connection parameters used to create ConnectionPool
      def initialize(opts)
        initialize_options(opts)

        @connection =
          @options.fetch(:connection, {})
      end
    end
  end
end
