defmodule MessageTest do
  use ExUnit.Case

  alias MessageStore.{Fixtures, Message}

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

  test "should create event message with type as string" do
    message = Fixtures.message()

    event_data = Message.build(message)

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert is_nil(event_data.correlation_id)
    assert is_nil(event_data.causation_id)
  end

  test "should create event message with type as atom" do
    message = Fixtures.message(type: FakeCommand)

    event_data = Message.build(message)

    assert event_data.event_type == Atom.to_string(message.type)
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert is_nil(event_data.correlation_id)
    assert is_nil(event_data.causation_id)
  end

  test "should create event with causation_id and correlation_id" do
    message = Fixtures.message(correlation_id: "test-1234", causation_id: "test-3490")

    event_data = Message.build(message)

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
    assert event_data.correlation_id == message.correlation_id
    assert event_data.causation_id == message.causation_id
  end

  test "should not copy any data from recorded event to source event" do
    recorded_event = Fixtures.recorded_event(event_type: "Test", stream_uuid: "test-123")
    message = Fixtures.message()

    event_data = Message.copy(message, recorded_event, [])

    assert event_data.event_type == message.type
    assert event_data.data == message.data
    assert event_data.metadata == message.metadata
  end

  test "should copy all metadata from recorded event to source event" do
    data = {:data, [:foo]}
    metadata = :metadata

    recorded_event =
      Fixtures.recorded_event(
        event_type: "Test",
        stream_uuid: "test-123",
        metadata: %{baz: "bar"}
      )

    message = Fixtures.message()

    event_data = Message.copy(message, recorded_event, [metadata, data])

    assert event_data.event_type == message.type
    assert event_data.data == expected_result(message, recorded_event, data)
    assert event_data.metadata == expected_result(message, recorded_event, metadata)
  end

  test "should copy some metadata from recorded event to source event" do
    data = {:data, [:foo]}
    metadata = {:metadata, [:boo]}

    recorded_event =
      Fixtures.recorded_event(
        event_type: "Test",
        stream_uuid: "test-123",
        metadata: %{bar: "baz", boo: "bam"}
      )

    message = Fixtures.message()

    event_data = Message.copy(message, recorded_event, [:correlation_id, metadata, data])

    assert event_data.event_type == message.type
    assert event_data.data == expected_result(message, recorded_event, data)
    assert event_data.metadata == expected_result(message, recorded_event, metadata)
    assert event_data.correlation_id == recorded_event.correlation_id
  end

  test "should not follow any data from recorded event to source event" do
    recorded_event =
      Fixtures.recorded_event(
        correlation_id: "abcd1234",
        event_type: "Test",
        stream_uuid: "test-123"
      )

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

    recorded_event =
      Fixtures.recorded_event(
        event_type: "Test",
        correlation_id: "09345",
        stream_uuid: "test-123",
        metadata: %{bar: "baz", boo: "bam"}
      )

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

    recorded_event =
      Fixtures.recorded_event(
        correlation_id: "12345",
        stream_uuid: "test-123",
        event_type: "Test",
        metadata: %{bar: "baz", boo: "bam"}
      )

    message = Fixtures.message()

    event_data = Message.follow(message, recorded_event, [metadata, data])

    assert event_data.event_type == message.type
    assert event_data.data == expected_result(message, recorded_event, data)
    assert event_data.metadata == expected_result(message, recorded_event, metadata)
    assert event_data.correlation_id == recorded_event.correlation_id
    assert event_data.causation_id == recorded_event.event_id
  end

  test "should set correlation_id to event_id when source event is root event" do
    message = Fixtures.message()
    recorded_event = Fixtures.recorded_event(event_type: "Test", stream_uuid: "test-123")

    assert is_nil(recorded_event.correlation_id)
    assert is_nil(recorded_event.causation_id)

    event = Message.follow(message, recorded_event, [])

    assert event.correlation_id == recorded_event.event_id
    assert event.causation_id == recorded_event.event_id
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
