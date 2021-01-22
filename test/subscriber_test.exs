defmodule SubscriberTest do
  use ExUnit.Case
  doctest MessageStore.Subscriber

  alias EventStore.RecordedEvent

  alias MessageStore.Subscriber

  alias MessageStore.Fixtures

  defmodule FakeMessageStore do
    use GenServer

    @doc false
    def start_link() do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    @impl true
    def init(state) do
      {:ok, state}
    end

    @impl true
    def handle_call({:subscribe, subscriber_name, opts}, _from, state) do
      new_state =
        opts
        |> Map.new()
        |> Map.put(:subscriber_name, subscriber_name)

      {:reply, {:ok, nil}, Map.merge(state, new_state)}
    end

    @impl true
    def handle_call({:filter, message}, _from, %{selector: selector} = state) do
      {:reply, selector.(message), state}
    end

    @impl true
    def handle_call(:state, _from, state) do
      {:reply, state, state}
    end

    def subscribe_to_all_streams(subscriber_name, _pid, opts) do
      GenServer.call(__MODULE__, {:subscribe, subscriber_name, opts})
    end

    def filter(message) do
      GenServer.call(__MODULE__, {:filter, message})
    end

    def state() do
      GenServer.call(__MODULE__, :state)
    end
  end

  test "should select only messages for particular stream" do
    {:ok, message_store_pid} = FakeMessageStore.start_link()
    Process.unlink(message_store_pid)

    settings = %{
      message_store: FakeMessageStore,
      subscriber_name: "subscriber",
      stream_name: "test"
    }

    _ = Subscriber.init(settings)

    assert FakeMessageStore.filter(%RecordedEvent{stream_uuid: "test-1234"})
    refute FakeMessageStore.filter(%RecordedEvent{stream_uuid: "foo-1234"})

    GenServer.stop(message_store_pid)
  end

  test "should select only messages for particular stream and same origin" do
    {:ok, message_store_pid} = FakeMessageStore.start_link()
    Process.unlink(message_store_pid)

    settings = %{
      message_store: FakeMessageStore,
      subscriber_name: "subscriber",
      stream_name: "test",
      origin_stream_name: "foo"
    }

    _ = Subscriber.init(settings)

    assert FakeMessageStore.filter(%RecordedEvent{
             stream_uuid: "test-1234",
             metadata: %{origin_stream_name: "foo-09876"}
           })

    refute FakeMessageStore.filter(%RecordedEvent{
             stream_uuid: "test-1234",
             metadata: %{origin_stream_name: "bar-09876"}
           })

    GenServer.stop(message_store_pid)
  end

  test "should reject message when origin stream name is missing" do
    {:ok, message_store_pid} = FakeMessageStore.start_link()
    Process.unlink(message_store_pid)

    settings = %{
      message_store: FakeMessageStore,
      subscriber_name: "subscriber",
      stream_name: "test",
      origin_stream_name: "foo"
    }

    _ = Subscriber.init(settings)

    refute FakeMessageStore.filter(%RecordedEvent{
             stream_uuid: "test-1234",
             metadata: %{}
           })

    GenServer.stop(message_store_pid)
  end

  test "should select only messages for particular stream and specified address" do
    {:ok, message_store_pid} = FakeMessageStore.start_link()
    Process.unlink(message_store_pid)

    settings = %{
      message_store: FakeMessageStore,
      subscriber_name: "subscriber",
      stream_name: "test",
      address: "foo.bar.org"
    }

    _ = Subscriber.init(settings)

    assert FakeMessageStore.filter(%RecordedEvent{
             stream_uuid: "test-1234",
             metadata: %{recipient: "foo.bar.org"}
           })

    refute FakeMessageStore.filter(%RecordedEvent{
             stream_uuid: "test-1234",
             metadata: %{recipient: "www.example.com"}
           })

    GenServer.stop(message_store_pid)
  end

  test "should reject message when recipient is missing" do
    {:ok, message_store_pid} = FakeMessageStore.start_link()
    Process.unlink(message_store_pid)

    settings = %{
      message_store: FakeMessageStore,
      subscriber_name: "subscriber",
      stream_name: "test",
      address: "foo.bar.org"
    }

    _ = Subscriber.init(settings)

    refute FakeMessageStore.filter(%RecordedEvent{
             stream_uuid: "test-1234",
             metadata: %{}
           })

    GenServer.stop(message_store_pid)
  end

  test "should rename event store name to name for subscribe to named eventstore" do
    {:ok, message_store_pid} = FakeMessageStore.start_link()
    Process.unlink(message_store_pid)

    settings = %{
      message_store: FakeMessageStore,
      subscriber_name: "subscriber",
      stream_name: "test",
      event_store_name: FooStore
    }

    _ = Subscriber.init(settings)

    state = FakeMessageStore.state()

    assert state.name == FooStore

    GenServer.stop(message_store_pid)
  end

  describe "Messages processing" do
    defmodule TestHandler do
      @moduledoc false

      use MessageStore.MessageHandler

      def handle_message(%RecordedEvent{event_type: "Test"} = message, _settings) do
        send(self(), {:message_handled, message})

        {:ok, message}
      end
    end

    defmodule ErrorTestHandler do
      @moduledoc false

      use MessageStore.MessageHandler

      def handle_message(%RecordedEvent{event_type: "Test"} = message, _settings) do
        send(self(), {:message_handled, message})

        {:error, "ERROR"}
      end
    end

    defmodule TestMessageStore do
      @moduledoc false

      def ack(subscription, arg2) do
        send(self(), {:ack, subscription, arg2})

        :ok
      end
    end

    defmodule ErrorTestMessageStore do
      @moduledoc false

      def ack(subscription, arg2) do
        send(self(), {:ack, subscription, arg2})

        {:error, "ERROR"}
      end
    end

    test "should succeed" do
      message1 =
        Fixtures.recorded_event(
          stream_uuid: "test-123",
          data: %{},
          event_type: "Test",
          event_number: 1
        )

      message2 =
        Fixtures.recorded_event(
          stream_uuid: "test-123",
          data: %{},
          event_type: "Test",
          event_number: 2
        )

      messages = [message1, message2]

      settings = %{
        handlers: TestHandler,
        message_store: TestMessageStore,
        subscription: "PID",
        subscriber_name: "components:test"
      }

      result = Subscriber.handle_info({:events, messages}, settings)

      assert result == {:noreply, settings}

      assert_received {:ack, "PID", ^messages}
      assert_received {:message_handled, ^message1}
      assert_received {:message_handled, ^message2}
    end

    test "should exit if handler return error" do
      message1 =
        Fixtures.recorded_event(
          stream_uuid: "test-123",
          data: %{},
          event_type: "Test",
          event_number: 1
        )

      message2 =
        Fixtures.recorded_event(
          stream_uuid: "test-123",
          data: %{},
          event_type: "Test",
          event_number: 2
        )

      messages = [message1, message2]

      settings = %{
        handlers: ErrorTestHandler,
        message_store: TestMessageStore,
        subscription: "PID",
        subscriber_name: "components:test"
      }

      result = Subscriber.handle_info({:events, messages}, settings)

      assert result == {:stop, :error_in_message_processing, settings}

      refute_received {:ack, "PID", ^messages}
      assert_received {:message_handled, ^message1}
      refute_received {:message_handled, ^message2}
    end

    test "should shutdown if ack failed" do
      message1 =
        Fixtures.recorded_event(
          stream_uuid: "test-123",
          data: %{},
          event_type: "Test",
          event_number: 1
        )

      message2 =
        Fixtures.recorded_event(
          stream_uuid: "test-123",
          data: %{},
          event_type: "Test",
          event_number: 2
        )

      messages = [message1, message2]

      settings = %{
        handlers: TestHandler,
        message_store: ErrorTestMessageStore,
        subscription: "PID",
        subscriber_name: "components:test"
      }

      result = Subscriber.handle_info({:events, messages}, settings)

      assert result == {:stop, :shutdown, settings}

      assert_received {:ack, "PID", ^messages}
      assert_received {:message_handled, ^message1}
      assert_received {:message_handled, ^message2}
    end
  end
end
