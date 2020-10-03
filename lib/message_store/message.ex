defmodule MessageStore.Message do
  @moduledoc """
  A module for build, copy and folow event data.
  """

  alias EventStore.EventData

  def build(event) when is_map(event) do
    data = Map.fetch!(event, :data)

    %EventData{
      event_type: event |> Map.fetch!(:type) |> to_string(),
      data: data,
      metadata: Map.fetch!(event, :metadata),
      causation_id: Map.get(event, :causation_id, data.id),
      correlation_id: Map.get(event, :correlation_id, data.id)
    }
  end
end
