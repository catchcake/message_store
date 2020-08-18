defmodule MessageStore do
  @moduledoc """
  A module for interactions with message store
  """

  alias EventStore.{EventData, RecordedEvent}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use EventStore, opts

      def fetch(
            stream_name,
            projection,
            read \\ &read_stream_forward/1,
            project \\ &MessageStore.project/2
          )
          when is_binary(stream_name) and is_atom(projection) and is_function(project, 2) and
                 is_function(read, 1) do
        stream_name
        |> read.()
        |> Result.catch_error(:stream_not_found, fn _ -> {:ok, []} end)
        |> Result.map(&project.(&1, projection))
      end
    end
  end

  def project(messages, projection) when is_list(messages) and is_atom(projection) do
    Enum.reduce(
      messages,
      projection.init(),
      &projection.handle_message/2
    )
  end

  def to_result(:ok, value) do
    {:ok, value}
  end

  def to_result({:error, _err} = error, _value) do
    error
  end

  def create_event_data(event) when is_map(event) do
    data = Map.fetch!(event, :data)

    %EventData{
      event_type: event |> Map.fetch!(:type) |> to_string(),
      data: data,
      metadata: Map.fetch!(event, :metadata),
      causation_id: Map.get(event, :causation_id, data.id),
      correlation_id: Map.get(event, :correlation_id, data.id)
    }
  end

  def create_event_data(event, %RecordedEvent{
        correlation_id: correlation_id,
        event_id: causation_id
      })
      when is_map(event) do
    event
    |> Map.put(:correlation_id, correlation_id)
    |> Map.put(:causation_id, causation_id)
    |> create_event_data()
  end

  def category(stream_name) when is_binary(stream_name) do
    stream_name
    |> String.split("-")
    |> List.first()
  end

  def stream_name_to_id(stream_name) when is_binary(stream_name) do
    stream_name
    |> String.split("-", parts: 2)
    |> List.last()
  end

  @spec expected_version(String.t()) :: Result.t(term(), integer())
  def expected_version(stream_uuid) when is_binary(stream_uuid) do
    stream_uuid
    |> EventStore.stream_forward()
    |> stream_length()
  end

  defp stream_length({:error, _} = error) do
    error
  end

  defp stream_length(events) do
    events
    |> Enum.to_list()
    |> length()
    |> Result.ok()
  end
end
