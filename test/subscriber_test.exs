defmodule SubscriberTest do
  use ExUnit.Case
  doctest MessageStore.Subscriber

  alias EventStore.RecordedEvent

  alias MessageStore.Subscriber

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
end
