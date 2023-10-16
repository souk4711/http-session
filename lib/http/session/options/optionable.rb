class HTTP::Session
  class Options
    module Optionable
      def initialize_options(opts)
        @options =
          case opts
          when nil, false then {enabled: false}
          when true then {enabled: true}
          else opts
          end

        @enabled =
          @options.fetch(:enabled, true)
      end

      def enabled?
        @enabled
      end
    end
  end
end
