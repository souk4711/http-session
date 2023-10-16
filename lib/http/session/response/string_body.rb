class HTTP::Session
  class Response < SimpleDelegator
    class StringBody
      extend Forwardable

      def_delegator :to_s, :empty?

      def initialize(contents)
        @contents = contents
      end

      def to_s
        @contents
      end
      alias_method :to_str, :to_s
    end
  end
end
