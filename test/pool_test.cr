require "./test_helper"

class PoolTest < Minitest::Test
  def test_initialize
    pool = Pool.new { Conn.new }
    assert_equal 5, pool.capacity
    assert_equal 5.0, pool.timeout

    pool = Pool.new(capacity: 2, timeout: 0.1) { Conn.new }
    assert_equal 2, pool.capacity
    assert_equal 0.1, pool.timeout
  end

  def test_checkout_and_checkin
    pool = Pool.new(capacity: 5) { Conn.new }
    assert_equal 5, pool.capacity
    assert_equal 5, pool.pending

    conn = pool.checkout
    assert conn.is_a?(Conn)
    assert_equal 5, pool.capacity
    assert_equal 4, pool.pending

    pool.checkin(conn)
    assert_equal 5, pool.pending
  end

  def test_waits_for_instance_to_be_unavailable
    pool = Pool.new(capacity: 1, timeout: 0.01) { Conn.new }

    spawn do
      assert conn = pool.checkout
      sleep 0.001
      pool.checkin(conn)
    end

    async do
      assert conn = pool.checkout
    end

    wait
  end

  def test_timeout_waiting_for_instance_to_be_available
    pool = Pool.new(capacity: 2, timeout: 0.001) { Conn.new }
    assert pool.checkout.is_a?(Conn)
    assert pool.checkout.is_a?(Conn)
    assert_raises(IO::Timeout) { pool.checkout }
  end

  def test_lazily_starts_instances
    pool = Pool.new(capacity: 100) { Conn.new }
    assert_equal 0, pool.size
    assert_equal 100, pool.pending

    3.times { pool.checkout }
    assert_equal 3, pool.size
    assert_equal 97, pool.pending
  end

  def test_reuses_instances_as_long_as_needed
    pool = Pool.new(capacity: 100) { Conn.new }
    assert_equal 0, pool.size
    assert_equal 100, pool.pending

    99.times { pool.checkin(pool.checkout) }
    assert_equal 1, pool.size
    assert_equal 100, pool.pending
  end

  def test_starts_all_instances
    pool = Pool.new(capacity: 10) { Conn.new }
    pool.start_all
    assert_equal 10, pool.size
    assert_equal 10, pool.pending
  end
end
