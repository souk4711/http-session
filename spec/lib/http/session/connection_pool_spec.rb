RSpec.describe HTTP::Session::ConnectionPool do
  let(:conn_klass) { Struct.new(:id) }
  let(:conn_create_blk) { ->(id) { conn_klass.new(id) } }
  let(:default_options) { {host: "https://example.com"} }

  describe "#with" do
    it "reuse a free connection" do
      id = 0
      pool = described_class.new(default_options.merge(maxsize: 2), &->(_) { conn_create_blk.call(id += 1) })

      thrs = []
      thrs << Thread.new { pool.with {} } # conn#1
      sleep 0.5

      # 0.0 ->  obtain conn#1
      # 0.0 -> release conn#1
      # 0.5 ->  obtain conn#1
      # 0.5 -> release conn#1
      pool.with { |conn| expect(conn.id).to eq(1) } # conn#1
    ensure
      thrs.each(&:join)
    end

    it "create a new connection if the pool does not reach @maxsize" do
      id = 0
      pool = described_class.new(default_options.merge(maxsize: 2), &->(_) { conn_create_blk.call(id += 1) })

      thrs = []
      thrs << Thread.new { pool.with { |conn| sleep 2 } } # conn#1
      sleep 0.5

      # 0.0 ->  obtain conn#1
      # 0.5 ->  obtain conn#2
      # 0.5 -> release conn#2
      # 2.0 -> release conn#1
      pool.with { |conn| expect(conn.id).to eq(2) } # conn#2
    ensure
      thrs.each(&:join)
    end

    it "block when no available connection" do
      id = 0
      pool = described_class.new(default_options.merge(maxsize: 1), &->(_) { conn_create_blk.call(id += 1) })

      thrs = []
      thrs << Thread.new { pool.with { |conn| sleep 2 } } # conn#1
      sleep 0.5

      # 0.0 ->  obtain conn#1
      # 0.5 ->   ---- t1 ----
      # 2.0 -> release conn#1
      # 2.0 ->  obtain conn#1
      # 2.0 -> release conn#1
      # 2.0 ->   ---- t2 ----
      t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      pool.with { |conn| expect(conn.id).to eq(1) } # conn#1
      t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(t2 - t1).to be > 1
    ensure
      thrs.each(&:join)
    end

    it "last in first out" do
      id = 0
      pool = described_class.new(default_options.merge(maxsize: 2), &->(_) { conn_create_blk.call(id += 1) })

      thrs = []
      thrs << Thread.new { pool.with { |conn| sleep 1 } } # conn#1
      thrs << Thread.new { pool.with { |conn| sleep 2 } } # conn#2
      thrs.each(&:join)

      # 0.0 ->  obtain conn#1
      # 0.0 ->  obtain conn#2
      # 1.0 -> release conn#1
      # 2.0 -> release conn#2
      # 2.5 ->  obtain conn#2
      # 2.5 -> release conn#2
      pool.with { |conn| expect(conn.id).to eq(2) } # conn#2
    end

    it "timeout" do
      id = 0
      pool = described_class.new(default_options.merge(maxsize: 1), &->(_) { conn_create_blk.call(id += 1) })

      thrs = []
      thrs << Thread.new { pool.with { |conn| sleep 2 } } # conn#1
      sleep 0.5

      # 0.0 ->  obtain conn#1
      # 1.5 ->  -- timeout --
      # 2.0 -> release conn#1
      expect do
        pool.with(timeout: 1) {} # conn#1
      end.to raise_error(HTTP::Session::Exceptions::PoolTimeoutError, "Waited 1 sec, 0/1 available")
    ensure
      thrs.each(&:join)
    end
  end
end
