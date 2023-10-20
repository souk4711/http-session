class HTTP::Session
  class Options
    class CookiesOption
      include Optionable

      # @!attribute [r] jar
      #   @return [HTTP::CookieJar]
      attr_reader :jar

      # @param [Hash] opts
      # @option opts [HTTP::CookieJar] :jar
      def initialize(opts)
        initialize_options(opts)

        # CookieJar
        @jar =
          if enabled?
            jar = @options[:jar]
            lookup_jar(jar)
          end
      end

      private

      def lookup_jar(jar)
        case jar
        when Hash
          HTTP::CookieJar.new(**jar)
        when nil
          HTTP::CookieJar.new
        else
          jar
        end
      end
    end
  end
end
