class HTTP::Session
  class ConnectionPool
    include MonitorMixin

    DEFAULT_POOL_TIMEOUT = 5
    DEFAULT_POOL_MAXSIZE = 5
    DEFAULT_CONN_KEEP_ALIVE_TIMEOUT = 5

    # The number of connections can be reused.
    attr_reader :maxsize

    # Returns a new instance of ConnectionPool.
    #
    # @param [Hash] opts
    def initialize(opts, &blk)
      super()

      @host = opts.fetch(:host)
      @timeout = opts.fetch(:timeout, DEFAULT_CONN_KEEP_ALIVE_TIMEOUT)
      @maxsize = opts.fetch(:maxsize, DEFAULT_POOL_MAXSIZE)

      @create_blk = blk
      @created = 0
      @que = []
      @resource = new_cond
    end

    # Obtain a connection.
    def with(timeout: DEFAULT_POOL_TIMEOUT, &blk)
      conn = checkout(timeout: timeout)
      blk.call(conn)
    ensure
      checkin(conn) if conn
    end

    # The number of connections available.
    def size
      @maxsize - @created + @que.size
    end

    private

    def checkout(timeout:)
      deadline = current_time + timeout

      synchronize do
        loop do
          # Reuse a free connection.
          if @que.size > 0
            break @que.pop
          end

          # Create a new connection if the pool does not reach @maxsize.
          if @created < @maxsize
            @created += 1
            break make_conn
          end

          # .
          to_wait = deadline - current_time
          raise HTTP::Session::Exceptions::PoolTimeoutError, "Waited #{timeout} sec, #{size}/#{maxsize} available" if to_wait <= 0

          # Block until a connection is put back to @que.
          @resource.wait(to_wait)
        end
      end
    end

    def checkin(conn)
      synchronize do
        # Put back to @que.
        @que.push(conn)

        # Wakes up all threads waiting for this resource.
        @resource.broadcast
      end
    end

    def make_conn
      opts = {persistent: @host, keep_alive_timeout: @timeout}
      @create_blk.call(opts)
    end

    def current_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
