defmodule StreamTest do
  @moduledoc false

  use ExUnit.Case
  doctest MessageStore.Stream

  alias MessageStore.{Message, Stream}

  setup do
    {:ok, message_store} = TestMessageStore.start_link()

    opts = EventStore.Config.lookup(TestMessageStore)
    conn = Keyword.fetch!(opts, :conn)

    {:ok, conn: conn, opts: opts}
  end

  test "read/3 should return recorded events with global position", %{conn: conn, opts: opts} do
    streams = random_streams(3)
    put_events_to_database(streams)

    for stream <- streams do
      assert Stream.read(conn, stream, opts) == expected_events(stream)
    end
  end

  defp put_events_to_database(streams) do
    event_types = random_event_types()

    1..100
    |> Enum.map(&random_event(&1, event_types))
    |> Enum.map(fn msg ->
      TestMessageStore.append_to_stream(Enum.random(streams), :any_version, [msg])
    end)
  end

  defp random_event_types() do
    1..10
    |> Enum.map(fn _ -> random_string(5) end)
    |> Enum.map(&String.capitalize/1)
  end

  defp random_string(length) do
    1..length
    |> Enum.map(fn _ -> Enum.random(?a..?z) end)
    |> to_string()
  end

  defp random_event(index, event_types) do
    event_type = Enum.random(event_types)

    Message.build(%{type: event_type, data: %{id: index, text: "TEST ##{index}"}, metadata: %{}})
  end

  defp random_streams(count) do
    Enum.map(1..count, fn _ -> random_string(3 + :rand.uniform(5)) end)
  end

  defp expected_events(stream) do
    TestMessageStore.read_all_streams_forward()
    |> Result.map(&Enum.filter(&1, fn event -> event.stream_uuid == stream end))
  end
end
