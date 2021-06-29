defmodule ProjectionTest do
  @moduledoc false
  use ExUnit.Case
  doctest MessageStore.Projection

  alias MessageStore.Projection

  defmodule FooProjection do
    @moduledoc false
  end

  test "should return loaded projection" do
    result = Projection.load("foo-1234", FooProjection, &fetch/2, &Function.identity/1)

    assert result == "FOO"

    assert_received {:fetched, "foo-1234", FooProjection}
  end

  defp fetch(stream, projection) do
    send(self(), {:fetched, stream, projection})

    {:ok, "FOO"}
  end
end
