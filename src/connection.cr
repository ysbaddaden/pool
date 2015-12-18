require "./pool"

# Sharing connections across coroutines.
#
# Connections will be checkout from the pool and tied to the current fiber,
# until they are checkin, and thus be usable by another coroutine. Connections
# may also be manually checkout and checkin.
class ConnectionPool(T) < Pool(T)
  # TODO: reap connection of dead coroutines that didn't checkin (or died before)
  # FIXME: thread safety

  # Returns true if a connection was checkout for the current coroutine.
  def active?
    connections.has_key?(Fiber.current.object_id)
  end

  # Returns the already checkout connection or checkout a connection then
  # attaches it to the current coroutine.
  def connection
    connections[Fiber.current.object_id] ||= checkout
  end

  # Releases the checkout connection for the current coroutine (if any).
  def release
    if conn = connections.delete(Fiber.current.object_id)
      checkin(conn)
    end
  end

  # Yields a connection.
  #
  # If a connection was already checkout for the curent coroutine, it will be
  # yielded. Otherwise a connection will be checkout and tied to the current
  # coroutine, passed to the block and eventually checkin.
  def connection
    fresh_connection = !active?
    yield connection
  ensure
    release if fresh_connection
  end

  private def connections
    @connections ||= {} of UInt64 => T
  end
end
