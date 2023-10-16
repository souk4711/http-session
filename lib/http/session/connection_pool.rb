class HTTP::Session
  class ConnectionPool
    # @param [Options::PersistentOption] options
    # @param [HTTP::Session] session
    def initialize(options, session)
      super()

      @options = options
      @session = session
    end

    def with(uri, &blk)
      blk.call(conn)
    end

    private

    def conn
      HTTP::Session::Client.new(@session.default_options.http, @session)
    end
  end
end
