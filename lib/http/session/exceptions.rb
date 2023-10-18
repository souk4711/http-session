class HTTP::Session
  module Exceptions
    Error = Class.new(HTTP::Error)
    PoolTimeoutError = Class.new(Error)
  end
end
