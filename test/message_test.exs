defmodule MessageTest do
  use ExUnit.Case

  alias MessageStore.{Fixtures, Message}

  test "should create event message with type as string" do
    message = Fixtures.message()

    event_data = Message.build(message)

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
  end

  test "should create event message with type as atom" do
    message = Fixtures.message() |> Map.put(:type, FakeCommand)

    event_data = Message.build(message)

    assert event_data.event_type == Atom.to_string(message.type)
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
  end

  test "should not follow any data from recorded event to source event" do
    recorded_event = Fixtures.recorded_event()
    message = Fixtures.message()

    event_data = Message.follow(message, recorded_event, [])

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end

  test "should follow all metadata from recorded event to source event" do
    data = {:data, [:foo]}
    metadata = :metadata
    recorded_event = Fixtures.recorded_event()
    message = Fixtures.message()

    event_data = Message.follow(message, recorded_event, [metadata, data])

    assert event_data.event_type == message.type
    assert event_data.data == expected_result(message, recorded_event, data)
    assert event_data.metadata == expected_result(message, recorded_event, metadata)
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end

  test "should follow some metadata from recorded event to source event" do
    data = {:data, [:foo]}
    metadata = {:metadata, [:boo]}
    recorded_event = Fixtures.recorded_event()
    message = Fixtures.message()

    event_data = Message.follow(message, recorded_event, [metadata, data])

    assert event_data.event_type == message.type
    assert event_data.data == expected_result(message, recorded_event, data)
    assert event_data.metadata == expected_result(message, recorded_event, metadata)
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end

  # Private

  defp expected_result(message, recorded_event, {payload, payload_keys}) do
    re_payload = Map.take(recorded_event[payload], payload_keys)

    Map.merge(message[payload], re_payload)
  end

  defp expected_result(message, recorded_event, payload) when payload in [:data, :metadata] do
    Map.merge(message[payload], recorded_event[payload])
  end
end
