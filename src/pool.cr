# Generic pool.
#
# It will create N instances that can be checkin then checkout. Trying to
# checkout an instance from an empty pool will block until another coroutine
# checkin an instance back, up until a timeout is reached.
class Pool(T)
  # TODO: lazily create connections
  # TODO: shutdown (close all connections)
  # FIXME: thread safety

  getter :capacity
  getter :timeout
  private getter :pool

  def initialize(@capacity = 5 : Int, @timeout = 5.0 : Float, &block : -> T)
    @r, @w = IO.pipe(read_blocking: false, write_blocking: false)
    @r.read_timeout = @timeout

    buffer :: UInt8[1]
    @buffer = buffer.to_slice

    @pool = [] of T
    capacity.times { pool << block.call }
  end

  # Returns how many instances are available for checkout.
  def pending
    pool.size
  end

  # Checkout an instance from the pool. Blocks until an instance is available if
  # all instances are busy. Eventually raises an `IO::Timeout` error.
  def checkout : T
    loop do
      return pool.shift if pool.any?
      @r.read(@buffer)
    end
  end

  # Checkin an instance back into the pool.
  def checkin(connection : T)
    unless pool.includes?(connection)
      pool.push(connection)
      @w << '.'
    end
  end
end
