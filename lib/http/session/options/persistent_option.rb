class HTTP::Session
  class Options
    class PersistentOption
      include Optionable

      # @param [Hash] opts
      def initialize(opts)
        initialize_options(opts)
      end
    end
  end
end
