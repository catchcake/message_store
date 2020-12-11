defmodule MessageStore.Stream do
  @moduledoc """
  A stream operations.
  """

  def read(stream_name) do
    nil
  end

  def query_read_stream() do
    """
    with event_ids as (
      select event_id
      from stream_events join streams using(stream_id)
      where streams.stream_uuid = $1
    )
    select *
    from event_ids
      join stream_events using(event_id)
      join events using(event_id)
    where stream_id=0;
    """
  end
end
