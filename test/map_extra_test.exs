defmodule MapExtraTest do
  @moduledoc false
  use ExUnit.Case

  alias MessageStore.MapExtra

  doctest MessageStore.MapExtra

  test "fetch_in!/2 - should raise error if given path don't exists" do
    assert_raise(MapExtra.PathError, fn -> MapExtra.fetch_in!(%{}, [:a, :b, :c]) end)
  end
end
