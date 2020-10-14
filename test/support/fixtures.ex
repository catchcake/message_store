defmodule MessageStore.Fixtures do
  @moduledoc """
  A data fixtures.
  """

  alias EventStore.RecordedEvent

  def recorded_event(opts \\ []) do
    %RecordedEvent{
      event_id: Keyword.get(opts, :event_id, Enum.random(1..100_000) |> to_string()),
      causation_id: Keyword.get(opts, :causation_id, nil),
      correlation_id: Keyword.get(opts, :correlation_id, nil),
      data: Keyword.get(opts, :data, %{foo: "bazinga"}),
      metadata: Keyword.get(opts, :metadata, %{baz: 10, boo: 20})
    }
  end

  def message(opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "RunTest"),
      data: Keyword.get(opts, :data, %{id: 1, foo: "bar"}),
      metadata: Keyword.get(opts, :metadata, %{baz: 1, bar: 2})
    }
    |> put_if_exists(:correlation_id, Keyword.get(opts, :correlation_id, nil))
    |> put_if_exists(:causation_id, Keyword.get(opts, :causation_id, nil))
  end

  defp put_if_exists(map, _key, nil) do
    map
  end

  defp put_if_exists(map, key, value) do
    Map.put(map, key, value)
  end
end
