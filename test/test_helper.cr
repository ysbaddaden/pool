require "minitest/autorun"

require "../src/pool"
require "../src/connection"

class Conn
  def method1
    1
  end

  def method2(x : String)
    x.size
  end

  def method3(&block : -> String)
    yield.size
  end
end

module AsyncTest
  @exception : Exception?

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
      break if @done
    end

    if exception = @exception
      raise exception
    end
  end

  def async(&block)
    @done = false

    spawn do
      begin
        block.call
      rescue ex
        @exception = ex
      ensure
        @done = true
      end
    end
  end
end

class Minitest::Test
  include AsyncTest
end
