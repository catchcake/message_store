defmodule MessageStore.Stream do
  @moduledoc """
  A stream operations.
  """

  import MessageStore, only: [is_conn: 1]

  def read(conn, stream_name, opts \\ [])
      when is_conn(conn) and is_binary(stream_name) and is_list(opts) do
    schema = Keyword.get(opts, :schema, "public")

    Postgrex.query(
      conn,
      query_read_stream(schema),
      [stream_name]
    )
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
end
