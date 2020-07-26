defmodule JsonSerializerTest do
  use ExUnit.Case
  doctest MessageStore.JsonSerializer

  alias MessageStore.JsonSerializer

  test "should serialize and deserialize data" do
    data = %{
      foo: [1, 2, 3],
      bar: %{
        baz: "test"
      },
      one: 1,
      two: "two"
    }

    assert JsonSerializer.deserialize(JsonSerializer.serialize(data), []) == data
  end
end
