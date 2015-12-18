require "./test_helper"

class ConnectionPoolTest < Minitest::Test
  def test_connection_is_tied_to_coroutine
    pool = ConnectionPool.new { Conn.new }
    pool.start_all

    async do
      conn = pool.connection
      assert_same conn, pool.connection
      assert pool.active?

      pool.release
      refute pool.active?
      refute_same conn, pool.connection
    end

    wait
  end

  def test_connection_with_block_checkout_fresh_connection
    pool = ConnectionPool.new { Conn.new }
    exception = nil

    async do
      pool.connection do |conn|
        assert_equal 4, pool.pending
        assert_same conn, pool.connection
      end

      assert_equal 5, pool.pending
      refute pool.active?
    end

    wait
  end

  def test_connection_with_block_uses_active_connection
    pool = ConnectionPool.new { Conn.new }

    async do
      conn1 = pool.connection

      pool.connection do |conn2|
        assert_equal 4, pool.pending
        assert_same conn1, conn2
        assert_same conn2, pool.connection
      end

      assert_equal 4, pool.pending
      assert pool.active?
    end

    wait
  end
end
