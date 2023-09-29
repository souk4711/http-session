require_relative "http/session"

module HTTP
  class << self
    # @return [HTTP::Session] a new instance of Session.
    def session(options = {})
      HTTP::Session.new(options)
    end
  end
end
