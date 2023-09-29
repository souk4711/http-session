require_relative "http/session"

module HTTP
  class << self
    # @return [Session] a new instance of Session.
    def session(options = {})
      HTTP::Session.new(options)
    end
  end
end
