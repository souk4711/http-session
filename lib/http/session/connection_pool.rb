class HTTP::Session
  class ConnectionPool
    extend Forwardable
    include MonitorMixin

    # @!method enabled?
    #   True when it is a shared cache.
    #   @return [Boolean]
    def_delegator :@options, :enabled?

    # @param [Options::PersistentOption] options
    # @param [HTTP::Session] session
    def initialize(options, session)
      super()
      @options = options
      @session = session
    end

    def with(uri, &blk)
      blk.call(make_conn)
    end

    private

    def make_conn
      HTTP::Session::Client.new(@session.default_options.http, @session)
    end
  end
end
