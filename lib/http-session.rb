require_relative "http/session"

module HTTP
  class << self
    def session(options = {})
      HTTP::Session.new(options)
    end
  end
end
