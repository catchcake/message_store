defmodule MessageStore.Message do
  @moduledoc """
  A module for build, copy and folow event data.
  """

  alias ExMaybe, as: Maybe

  defguard is_data_or_metadata(d) when d in [:data, :metadata]

  alias EventStore.EventData

  def build(event) when is_map(event) do
    %EventData{
      event_id: Map.get(event, :event_id),
      event_type: event |> Map.fetch!(:type) |> to_string(),
      data: Map.fetch!(event, :data),
      metadata: Map.fetch!(event, :metadata),
      causation_id: Map.get(event, :causation_id, nil),
      correlation_id: Map.get(event, :correlation_id, nil)
    }
  end

  def copy(event, recorded_event, copy_list) do
    copy_list
    |> Enum.map(&get_data_from(&1, recorded_event))
    |> Enum.reduce(build(event), &update_event(&1, &2))
  end

  def follow(event, recorded_event, copy_list)
      when is_map(event) and is_map(recorded_event) and is_list(copy_list) do
    event
    |> copy(recorded_event, copy_list)
    |> Map.put(
      :correlation_id,
      recorded_event.correlation_id |> Maybe.with_default(recorded_event.event_id)
    )
    |> Map.put(:causation_id, recorded_event.event_id)
  end

  # Private

  defp get_data_from(key, map) when is_atom(key) and is_map(map) do
    {key, Map.get(map, key)}
  end

  defp get_data_from({domd, keys}, map)
       when is_data_or_metadata(domd) and is_map(map) and is_list(keys) do
    {domd, Map.get(map, domd) |> Map.take(keys)}
  end

  defp update_event({key, map}, event) when is_data_or_metadata(key) and is_map(map) do
    updated_event_domd = Map.merge(event[key], map)

    Map.put(event, key, updated_event_domd)
  end

  defp update_event({key, data}, event) when is_atom(key) do
    Map.put(event, key, data)
  end
end
