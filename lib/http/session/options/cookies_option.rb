class HTTP::Session
  class Options
    class CookiesOption
      # @param [Hash] options
      def initialize(options)
        options =
          case options
          when nil, false then {enabled: false}
          when true then {enabled: true}
          else options
          end

        @enabled = options.fetch(:enabled, true)
      end

      # Indicates whether or not the session cookie feature is enabled.
      def enabled?
        @enabled
      end
    end
  end
end
