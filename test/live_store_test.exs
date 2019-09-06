defmodule LiveStoreTest do
  use ExUnit.Case
  doctest LiveStore

  test "greets the world" do
    assert LiveStore.hello() == :world
  end
end
