class HTTP::Session
  class Options
    class CookiesOption
      include Optionable

      # @!attribute [r] jar
      #   @return [HTTP::CookieJar]
      attr_reader :jar

      # @param [Hash] opts
      def initialize(opts)
        initialize_options(opts)

        # CookieJar
        @jar =
          if enabled?
            lookup_jar
          end
      end

      private

      def lookup_jar
        HTTP::CookieJar.new
      end
    end
  end
end
