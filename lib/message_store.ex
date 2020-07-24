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
      event_type: event |> Map.fetch!(:type) |> Atom.to_string(),
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
end
