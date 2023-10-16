class HTTP::Session
  class Options
    class CookiesOption
      # @!attribute [r] jar
      #   @return [HTTP::CookieJar]
      attr_reader :jar

      # @param [Hash] options
      def initialize(options)
        options =
          case options
          when nil, false then {enabled: false}
          when true then {enabled: true}
          else options
          end

        # Enabled / Disabled
        @enabled = options.fetch(:enabled, true)

        # CookieJar
        @jar = lookup_jar if @enabled
      end

      # Indicates whether or not the session cookie feature is enabled.
      def enabled?
        @enabled
      end

      private

      def lookup_jar
        HTTP::CookieJar.new
      end
    end
  end
end
