defmodule WatermelonTest do
  use ExUnit.Case
  doctest Watermelon

  test "greets the world" do
    assert Watermelon.hello() == :world
  end
end
