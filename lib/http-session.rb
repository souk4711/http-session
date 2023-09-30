require_relative "http/session"

module HTTP
  class << self
    # @param [Hash] default_options
    # @option default_options [Boolean, Hash] :cookies session cookies option
    # @option default_options [Boolean, Hash] :cache session cache option
    # @option default_options [Hash] :http http client options
    # @return [Session] a new instance of Session.
    def session(default_options = {})
      HTTP::Session.new(default_options)
    end
  end
end
