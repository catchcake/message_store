defmodule MessageTest do
  use ExUnit.Case

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
end
