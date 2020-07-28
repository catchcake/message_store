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
    def handle_call({:subscribe, name, selector}, _from, state) do
      {:reply, {:ok, nil}, state |> Map.put(:name, name) |> Map.put(:selector, selector)}
    end

    @impl true
    def handle_call({:filter, message}, _from, %{selector: selector} = state) do
      {:reply, selector.(message), state}
    end

    def subscribe_to_all_streams(name, _pid, opts) do
      selector = Keyword.fetch!(opts, :selector)

      GenServer.call(__MODULE__, {:subscribe, name, selector})
    end

    def filter(message) do
      GenServer.call(__MODULE__, {:filter, message})
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
end
