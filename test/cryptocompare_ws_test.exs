defmodule CryptocompareWsTest do
  use ExUnit.Case
  doctest CryptocompareWs

  test "greets the world" do
    assert CryptocompareWs.hello() == :world
  end
end
