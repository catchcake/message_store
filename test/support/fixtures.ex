defmodule MessageStore.Fixtures do
  @moduledoc """
  A data fixtures.
  """

  alias EventStore.RecordedEvent

  def recorded_event(defaults) do
    event_number = Keyword.get(defaults, :event_number, :rand.uniform(1000))

    %RecordedEvent{
      causation_id: Keyword.get(defaults, :causation_id),
      correlation_id: Keyword.get(defaults, :correlation_id),
      created_at: Keyword.get(defaults, :created_at, DateTime.utc_now()),
      data: Keyword.get(defaults, :data, %{foo: "bazinga"}),
      event_id: Keyword.get(defaults, :event_id, UUID.uuid4()),
      event_number: event_number,
      event_type: Keyword.fetch!(defaults, :event_type),
      metadata: Keyword.get(defaults, :metadata),
      stream_uuid: Keyword.fetch!(defaults, :stream_uuid),
      stream_version: Keyword.get(defaults, :stream_version, event_number)
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
