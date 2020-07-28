defmodule MessageStoreTest do
  use ExUnit.Case
  # doctest MessageStore

  alias EventStore.RecordedEvent

  test "should create event message with type as string" do
    message = %{
      type: "RunTest",
      data: %{id: 1, foo: "bar"},
      metadata: %{baz: 1}
    }

    event_data = MessageStore.create_event_data(message)

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

    event_data = MessageStore.create_event_data(message)

    assert event_data.event_type == Atom.to_string(message.type)
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
  end

  test "should create correlation_id and causation_id based on source event" do
    recorded_event = %RecordedEvent{
      correlation_id: "12345",
      event_id: "67890"
    }

    message = %{
      type: "RunTest",
      data: %{id: 1, foo: "bar"},
      metadata: %{baz: 1}
    }

    event_data = MessageStore.create_event_data(message, recorded_event)

    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end
end
