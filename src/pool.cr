# Generic pool.
#
# It will create N instances that can be checkin then checkout. Trying to
# checkout an instance from an empty pool will block until another coroutine
# checkin an instance back, up until a timeout is reached.
class Pool(T)
  # TODO: shutdown (close all connections)

  # Returns how many instances can be started at maximum capacity.
  getter capacity : Int32

  # Returns how much time to wait for an instance to be available before raising
  # a Timeout exception.
  getter timeout : Time::Span

  # Returns how many instances are available for checkout.
  getter pending : Int32

  # Returns how many instances have been started.
  getter size : Int32

  private getter pool : Array(T)

  @[Deprecated("The 'timeout' shall now be a Time::Span instead of a Float64")]
  def self.new(capacity : Int32 = 5, timeout : Float64 = 5, &block : -> T)
    new(capacity, timeout.seconds, &block)
  end
  def self.new(capacity : Int32 = 5, &block : -> T)
    new(capacity, 5.seconds, &block)
  end

  def initialize(@capacity : Int32 = 5, timeout : Time::Span = 5.seconds, &block : -> T)
    @mutex = Mutex.new(:unchecked)
    @size = 0
    @pending = @capacity
    @pool = [] of T
    @channel = Channel(Int32).new(@capacity)
    @timeout = timeout
    @block = block
  end

  def start_all
    @mutex.synchronize do
      until size >= @capacity
        start_one(checkin: true)
      end
    end
  end

  # Checkout an instance from the pool. Blocks until an instance is available if
  # all instances are busy. Eventually raises an `IO::Timeout` error.
  def checkout : T
    loop do
      @mutex.synchronize do
        if pool.empty?
          return start_one(checkin: false) if under_capacity?
        else
          @channel.receive? # make sure to read from channel
          return pull_one?.not_nil!
        end
      end

      select
      when @channel.receive
        @mutex.synchronize do
          if obj = pull_one?
            return obj
          end
        end
      when timeout(@timeout)
        raise IO::TimeoutError.new
      end
    end
  end

  # Checkin an instance back into the pool.
  def checkin(connection : T) : Nil
    @mutex.synchronize do
      return if pool.includes?(connection)

      pool << connection
      @pending += 1

      @channel.send(1)
    end
  end

  private def under_capacity? : Bool
    size < @capacity
  end

  private def start_one(checkin : Bool) : T
    obj = @block.call
    @size += 1

    if checkin
      pool << obj
      @channel.send(1)
    else
      @pending -= 1
    end

    obj
  end

  private def pull_one? : T?
    if obj = pool.shift?
      @pending -= 1
      obj
    end
  end
end
