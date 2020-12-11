defmodule MessageStore.Stream do
  @moduledoc """
  A stream operations.
  """

  def read(stream_name) do
    # XXX: for testing purposes
    Postgrex.query(
      Core.MessageStore.Postgrex,
      query_read_stream("eventstore"),
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
    select *
    from event_ids
      join #{schema}.stream_events using(event_id)
      join #{schema}.events using(event_id)
    where stream_id=0;
    """
  end
end
