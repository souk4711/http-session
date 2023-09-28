require "http"

require_relative "session/configurable"
require_relative "session/exceptions"
require_relative "session/options"
require_relative "session/requestable"
require_relative "session/version"

class HTTP::Session
  include HTTP::Session::Configurable
  include HTTP::Session::Requestable

  def initialize(options = {})
    @options = HTTP::Session::Options.new(options)
  end

  def request(verb, uri, opts = {})
    c = HTTP::Client.new(@options.http)
    c.request(verb, uri, opts)
  end
end
