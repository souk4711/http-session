class HTTP::Session
  class Response < SimpleDelegator
    # @!attribute [rw] history
    #   @return [Array<Response>] a list of response objects holding the history of the redirection
    attr_accessor :history

    def initialize(*args)
      super

      @history = []
    end
  end
end
