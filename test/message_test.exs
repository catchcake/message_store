defmodule MessageTest do
  use ExUnit.Case

  alias EventStore.RecordedEvent
  alias MessageStore.Message

  test "should create event message with type as string" do
    message = %{
      type: "RunTest",
      data: %{id: 1, foo: "bar"},
      metadata: %{baz: 1}
    }

    event_data = Message.build(message)

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
  end

  test "should create event message with type as atom" do
    message = %{
      type: FakeCommand,
      data: %{id: 1, foo: "bar"},
      metadata: %{baz: 1}
    }

    event_data = Message.build(message)

    assert event_data.event_type == Atom.to_string(message.type)
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
  end

  test "should not copy from recorded event to source event" do
    recorded_event = %RecordedEvent{
      correlation_id: "12345",
      event_id: "67890"
    }

    message = %{
      type: "RunTest",
      data: %{id: 1, foo: "bar"},
      metadata: %{baz: 1}
    }

    event_data = Message.follow(message, recorded_event, [])

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    refute is_map_key(event_data, :event_id)
    refute event_data.correlation_id == recorded_event.correlation_id
  end

  test "should copy from recorded event to source event" do
    recorded_event = %RecordedEvent{
      causation_id: "111222",
      correlation_id: "12345",
      event_id: "67890"
    }

    message = %{
      type: "RunTest",
      data: %{id: 1, foo: "bar"},
      metadata: %{baz: 1}
    }

    event_data = Message.follow(message, recorded_event, [:correlation_id, :event_id])

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.event_id == recorded_event.event_id
    refute event_data.causation_id == recorded_event.causation_id
  end
end
