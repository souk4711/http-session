class HTTP::Session
  class PoolManager
    include MonitorMixin

    # Returns a new instance of PoolManager.
    #
    # @param [Options::PersistentOption] options
    # @param [HTTP::Session] session
    def initialize(options, session)
      super()
      @options = options
      @session = session
      @pools = {}
    end

    # Obtain a connection.
    def with(uri, &blk)
      return with_new_conn(&blk) unless @options.enabled?

      origin = HTTP::URI.parse(uri).origin
      return with_new_conn(&blk) unless connection_pool_usable?(origin)

      with_reusable_conn(origin, &blk)
    end

    private

    def with_new_conn(&blk)
      blk.call(make_conn)
    end

    def with_reusable_conn(origin, &blk)
      pool = connection_pool_from_origin(origin)
      pool.with { |conn| blk.call(conn) }
    end

    def make_conn(opts = {})
      opts = @session.default_options.http.merge(opts)
      HTTP::Session::Client.new(opts, @session)
    end

    def connection_pool_usable?(origin)
      opts = connection_pool_options_from_origin(origin)
      return false if opts.nil?
      return false if opts == false
      true
    end

    def connection_pool_options_from_origin(origin)
      return @options.pools[origin] if @options.pools.key?(origin)
      @options.pools["*"]
    end

    def connection_pool_from_origin(origin)
      synchronize do
        return @pools[origin] if @pools.key?(origin)

        opts = connection_pool_options_from_origin(origin).dup
        opts = {} if opts == true
        opts[:host] = origin
        @pools[origin] = ConnectionPool.new(opts, &->(conn_opts) {
          make_conn(conn_opts)
        })
      end
    end
  end
end
