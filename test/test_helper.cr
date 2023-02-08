require "minitest/autorun"

require "../src/pool"
require "../src/connection"

class Conn
end

module AsyncTest
  @exception : Exception?
  @mutex = Mutex.new

  def before_setup
    super
    @done = @exception = nil
  end

  def after_teardown
    @done = @exception = nil
    super
  end

  def wait
    loop do
      sleep 0
      break if @mutex.synchronize { @done }
    end

    if exception = @mutex.synchronize { @exception }
      raise exception
    end
  end

  def async(&block)
    @mutex.synchronize { @done = false }

    spawn do
      begin
        block.call
      rescue ex
        @mutex.synchronize { @exception = ex }
      ensure
        @mutex.synchronize { @done = true }
      end
    end
  end
end

class Minitest::Test
  include AsyncTest
end
