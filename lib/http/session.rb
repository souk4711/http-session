require "http"

require_relative "session/configurable"
require_relative "session/exceptions"
require_relative "session/options"
require_relative "session/version"

class HTTP::Session
  include HTTP::Session::Configurable

  def initialize(options = {})
    @options = HTTP::Session::Options.new(options)
  end
end
