defmodule MessageTest do
  use ExUnit.Case

  alias MessageStore.{Fixtures, Message}

  doctest MessageStore.Message

  defmodule FakeMessageStore do
    @moduledoc false

    def append_to_stream(stream_name, version, messages) do
      send(self(), {:called_append_to_stream, {stream_name, version, messages}})

      :ok
    end
  end

  test "should create event type from module name" do
    assert Message.type_from_module(Foo.Bar.Baz) == "Baz"
  end

  test "should raise error when atom is nil, true or false" do
    assert_raise FunctionClauseError, fn -> Message.type_from_module(nil) end
    assert_raise FunctionClauseError, fn -> Message.type_from_module(true) end
    assert_raise FunctionClauseError, fn -> Message.type_from_module(false) end
  end

  test "write/4 - should call append_to_stream" do
    stream_name = "test-123"
    messages = [%{}]

    assert Message.write(FakeMessageStore, stream_name, messages) == {:ok, stream_name}

    assert_receive {:called_append_to_stream, _}
  end

  test "write/4 - should prepare message list from one message" do
    stream_name = "test-123"

    assert Message.write(FakeMessageStore, stream_name, %{}) == {:ok, stream_name}

    assert_receive {:called_append_to_stream, {_, _, [%{}]}}
  end

  test "write/4 - should fill version parameter when is omitted" do
    stream_name = "test-123"
    messages = [%{}]

    assert Message.write(FakeMessageStore, stream_name, messages) == {:ok, stream_name}

    assert_receive {:called_append_to_stream, {_, :any_version, _}}
  end

  test "write/4 - should raise error when wrong version is given" do
    stream_name = "test-123"
    messages = [%{}]

    assert_raise FunctionClauseError, fn ->
      Message.write(FakeMessageStore, stream_name, messages, -1)
    end
  end

  test "build/1 - should create event message with type as string" do
    message = Fixtures.message()

    event_data = Message.build(message)

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert is_nil(event_data.correlation_id)
    assert is_nil(event_data.causation_id)
  end

  test "build/1 - should create event message with type as atom" do
    message = Fixtures.message(type: FakeCommand)

    event_data = Message.build(message)

    assert event_data.event_type == Atom.to_string(message.type)
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert is_nil(event_data.correlation_id)
    assert is_nil(event_data.causation_id)
  end

  test "build/1 - should create event with causation_id and correlation_id" do
    message = Fixtures.message(correlation_id: "test-1234", causation_id: "test-3490")

    event_data = Message.build(message)

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert event_data.correlation_id == message.correlation_id
    assert event_data.causation_id == message.causation_id
  end

  test "copy/3 - should not copy any data from recorded event to source event" do
    recorded_event = Fixtures.recorded_event(event_type: "Test", stream_uuid: "test-123")

    event_data = Message.copy("Foo", recorded_event, [])

    assert event_data.event_type == "Foo"
    assert event_data.data == %{}
    assert event_data.metadata == %{}
  end

  test "copy/3 - should copy all metadata from recorded event to source event" do
    copy_list = [[:data, :foo], :metadata]

    recorded_event =
      Fixtures.recorded_event(
        event_type: "Test",
        stream_uuid: "test-123",
        data: %{foo: 1, bar: 2},
        metadata: %{baz: "bar"}
      )

    event_data = Message.copy("Foo", recorded_event, copy_list)

    assert event_data.event_type == "Foo"
    assert event_data.data == %{foo: 1}
    assert event_data.metadata == recorded_event.metadata
  end

  test "copy/3 - should copy some metadata from recorded event to source event" do
    copy_list = [:correlation_id, [:data, :foo], [:metadata, :boo]]

    recorded_event =
      Fixtures.recorded_event(
        event_type: "Test",
        stream_uuid: "test-123",
        data: %{foo: 1, bar: 2},
        metadata: %{bar: "baz", boo: "bam"}
      )

    event_data = Message.copy("Foo", recorded_event, copy_list)

    assert event_data.event_type == "Foo"
    assert event_data.data == %{foo: 1}
    assert event_data.metadata == %{boo: "bam"}
    assert event_data.correlation_id == recorded_event.correlation_id
  end

  test "follow/3 - should not follow any data from recorded event to source event" do
    recorded_event =
      Fixtures.recorded_event(
        correlation_id: "abcd1234",
        event_type: "Test",
        stream_uuid: "test-123"
      )

    event_data = Message.follow("Foo", recorded_event, [])

    assert event_data.event_type == "Foo"
    assert event_data.data == %{}
    assert event_data.metadata == %{}
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end

  test "follow/3 - should follow all metadata from recorded event to source event" do
    copy_list = [[:data, :foo], :metadata]

    recorded_event =
      Fixtures.recorded_event(
        event_type: "Test",
        correlation_id: "09345",
        stream_uuid: "test-123",
        data: %{foo: 1, bar: 2},
        metadata: %{bar: "baz", boo: "bam"}
      )

    event_data = Message.follow("Foo", recorded_event, copy_list)

    assert event_data.event_type == "Foo"
    assert event_data.data == %{foo: 1}
    assert event_data.metadata == recorded_event.metadata
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end

  test "follow/3 - should follow some metadata from recorded event to source event" do
    copy_list = [[:data, :foo], [:metadata, :boo]]

    recorded_event =
      Fixtures.recorded_event(
        correlation_id: "12345",
        stream_uuid: "test-123",
        event_type: "Test",
        data: %{foo: 1, bar: 2},
        metadata: %{bar: "baz", boo: "bam"}
      )

    event_data = Message.follow("Foo", recorded_event, copy_list)

    assert event_data.event_type == "Foo"
    assert event_data.data == %{foo: 1}
    assert event_data.metadata == %{boo: "bam"}
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end

  test "follow/3 - should set correlation_id to event_id when source event is root event" do
    recorded_event = Fixtures.recorded_event(event_type: "Test", stream_uuid: "test-123")

    assert is_nil(recorded_event.correlation_id)
    assert is_nil(recorded_event.causation_id)

    event = Message.follow("Foo", recorded_event, [])

    assert event.correlation_id == recorded_event.event_id
    assert event.causation_id == recorded_event.event_id
  end

  # Private
end
