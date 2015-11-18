# Pool

Generic (connection) pools for Crystal

## Getting Started

A pool tailored for sharing connections across coroutines.

Connections will be checkout from the pool and tied to the current fiber, until
they are checkin, and thus be usable by another coroutine. Otherwise they behave
the same than the generic pool.

```crystal
require "pg"
require "pool/connection"

pg = ConnectionPool.new(capacity: 25, timeout: 0.01) do
  PG.connect(ENV["DATABASE_URL"])
end
```

You may checkout as many connections in parallel as needed, then checkin the
connections as required:

```crystal
conn = pg.checkout
result = conn.exec("SELECT * FROM posts")
pg.checkin(conn)
```

You may checkout a single connection per coroutine. Trying to checkout another
one will always return the same single connection:

```crystal
conn = pg.connection
result = conn.exec("SELECT * FROM posts")
pg.release
```

You may also use a block, so the connection will be checkin back into the pool,
unless the connection was already checkout, in which case it will be passed to
the block, but not returned to the pool:

```crystal
pg.connection do |conn|
  result = conn.exec("SELECT * FROM posts")
end
```

## License

Licensed under the Apache License, Version 2.0
