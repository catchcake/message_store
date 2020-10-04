defmodule MessageStore.Fixtures do
  @moduledoc """
  A data fixtures.
  """

  alias EventStore.RecordedEvent

  def recorded_event() do
    %RecordedEvent{
      causation_id: 1,
      correlation_id: Enum.random(1..10_000) |> to_string(),
      data: %{foo: "bazinga"},
      event_id: Enum.random(1..100_000) |> to_string(),
      metadata: %{baz: 10, boo: 20}
    }
  end

  def message() do
    %{
      type: "RunTest",
      data: %{id: 1, foo: "bar"},
      metadata: %{baz: 1, bar: 2}
    }
  end
end
