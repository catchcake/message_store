defmodule MessageStore.Message do
  @moduledoc """
  A module for build, copy and folow message data.
  """

  alias EventStore.EventData
  alias ExMaybe, as: Maybe

  @type message() :: EventData.t()
  @type stream_name() :: String.t()
  @type version() :: EventStore.expected_version()

  defguard is_data_or_metadata(d) when d in [:data, :metadata]
  defguard is_version(version) when is_atom(version) or (is_integer(version) and version >= 0)
  defguard is_module_name(module) when is_atom(module) and module not in [nil, true, false]

  def build(message) when is_map(message) do
    %EventData{
      event_id: Map.get(message, :event_id),
      event_type: message |> Map.fetch!(:type) |> to_string(),
      data: Map.fetch!(message, :data),
      metadata: Map.fetch!(message, :metadata),
      causation_id: Map.get(message, :causation_id, nil),
      correlation_id: Map.get(message, :correlation_id, nil)
    }
  end

  def copy(message, recorded_message, copy_list) do
    copy_list
    |> Enum.map(&get_data_from(&1, recorded_message))
    |> Enum.reduce(build(message), &update_message(&1, &2))
  end

  def follow(message, recorded_message, copy_list)
      when is_map(message) and is_map(recorded_message) and is_list(copy_list) do
    message
    |> copy(recorded_message, copy_list)
    |> Map.put(
      :correlation_id,
      recorded_message.correlation_id |> Maybe.with_default(recorded_message.event_id)
    )
    |> Map.put(:causation_id, recorded_message.event_id)
  end

  @spec type_from_module(module()) :: String.t()
  def type_from_module(module) when is_module_name(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
  end

  @spec write(module(), stream_name(), message() | [message()], version()) ::
          Result.t(any(), any())
  def write(message_store, stream_name, message_or_messages, version \\ :any_version)

  def write(message_store, stream_name, messages, version)
      when is_atom(message_store) and is_binary(stream_name) and is_list(messages) and
             is_version(version) do
    stream_name
    |> message_store.append_to_stream(version, messages)
    |> MessageStore.to_result(stream_name)
  end

  def write(message_store, stream_name, message, version)
      when is_atom(message_store) and is_binary(stream_name) and is_map(message) and
             is_version(version),
      do: write(message_store, stream_name, [message], version)

  # Private

  defp get_data_from(key, map) when is_atom(key) and is_map(map) do
    {key, Map.get(map, key)}
  end

  defp get_data_from({domd, keys}, map)
       when is_data_or_metadata(domd) and is_map(map) and is_list(keys) do
    {domd, Map.get(map, domd) |> Map.take(keys)}
  end

  defp update_message({key, map}, message) when is_data_or_metadata(key) and is_map(map) do
    updated_message_domd = Map.merge(message[key], map)

    Map.put(message, key, updated_message_domd)
  end

  defp update_message({key, data}, message) when is_atom(key) do
    Map.put(message, key, data)
  end
end
