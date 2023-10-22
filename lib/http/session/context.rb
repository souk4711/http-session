class HTTP::Session
  class Context
    # @!attribute [r] follow
    #   @return [nil, FollowContext]
    attr_reader :follow

    # @param [Hash] options
    # @option options [nil, FollowContext] :follow
    def initialize(options)
      @follow = options[:follow]
    end
  end
end
