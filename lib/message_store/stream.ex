defmodule MessageStore.Stream do
  @moduledoc """
  A stream operations.
  """

  alias EventStore.RecordedEvent
  alias EventStore.Storage.Reader

  import MessageStore, only: [is_conn: 1]

  require Logger

  def read(conn, stream_name, opts \\ [])
      when is_conn(conn) and is_binary(stream_name) and is_list(opts) do
    schema = Keyword.get(opts, :schema, "public")
    serializer = Keyword.fetch!(opts, :serializer)

    conn
    |> Postgrex.query(query_read_stream(schema), [stream_name], opts)
    |> normalize_postgrex_result()
    |> Result.map(&Reader.EventAdapter.to_event_data/1)
    |> Result.catch_all_errors(&failed_to_read(&1, stream_name))
    |> Result.map(&deserialize_recorded_events(&1, serializer))
  end

  def query_read_stream(schema) do
    """
    with event_ids as (
      select event_id
      from #{schema}.stream_events join #{schema}.streams using(stream_id)
      where #{schema}.streams.stream_uuid = $1
    )
    select se.stream_version,
           e.event_id,
           $1 as stream_uuid,
           se.original_stream_version,
           e.event_type,
           e.correlation_id,
           e.causation_id,
           e.data,
           e.metadata,
           e.created_at
    from event_ids
      join #{schema}.stream_events as se using(event_id)
      join #{schema}.events as e using(event_id)
    where se.stream_id=0
    order by se.stream_version asc;
    """
  end

  defp normalize_postgrex_result({:ok, %Postgrex.Result{num_rows: 0}}), do: {:ok, []}
  defp normalize_postgrex_result({:ok, %Postgrex.Result{rows: rows}}), do: {:ok, rows}

  defp normalize_postgrex_result({:error, %Postgrex.Error{postgres: %{message: message}}}) do
    Logger.warn("Failed to read events from stream due to: " <> inspect(message))

    {:error, message}
  end

  defp normalize_postgrex_result({:error, %DBConnection.ConnectionError{message: message}}) do
    Logger.warn("Failed to read events from stream due to: " <> inspect(message))

    {:error, message}
  end

  defp normalize_postgrex_result({:error, error} = reply) do
    Logger.warn("Failed to read events from stream due to: " <> inspect(error))

    reply
  end

  defp failed_to_read(reason, stream_name) do
    Logger.warn(fn ->
      "Failed to read events from stream #{stream_name} due to: #{inspect(reason)}"
    end)

    {:error, reason}
  end

  defp deserialize_recorded_events(recorded_events, serializer) do
    Enum.map(recorded_events, &RecordedEvent.deserialize(&1, serializer))
  end
end
