require "./pool"

# Sharing connections across coroutines.
#
# Connections will be checkout from the pool and tied to the current fiber,
# until they are checkin, and thus be usable by another coroutine. Connections
# may also be manually checkout and checkin.
#
# TODO: reap connection of dead coroutines that didn't checkin (or died before)
class ConnectionPool(T) < Pool(T)
  @connections_mutex = Mutex.new(:unchecked)
  @connections = {} of Fiber => T

  # Returns true if a connection was checkout for the current Fiber.
  def active?
    @connections_mutex.synchronize { @connections.has_key?(Fiber.current) }
  end

  # Returns the already checkout connection or checkout a connection then
  # attaches it to the current Fiber.
  def connection
    if conn = @connections_mutex.synchronize { @connections[Fiber.current]? }
      conn
    else
      @connections_mutex.synchronize { @connections[Fiber.current] = checkout }
    end
  end

  # Releases the checkout connection for the current Fiber (if any).
  def release
    if conn = @connections_mutex.synchronize { @connections.delete(Fiber.current) }
      checkin(conn)
    end
  end

  # Yields a connection.
  #
  # If a connection was already checkout for the curent Fiber, it will be
  # yielded. Otherwise a connection will be checkout and tied to the current
  # Fiber, passed to the block and eventually checkin.
  def connection
    fresh_connection = !active?
    yield connection
  ensure
    release if fresh_connection
  end
end
