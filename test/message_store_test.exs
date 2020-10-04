defmodule MessageStoreTest do
  use ExUnit.Case
  doctest MessageStore

  defmodule TestProjection do
    @moduledoc false
    use MessageStore.Projection

    @impl true
    def init() do
      %{test: :init}
    end

    @impl true
    def handle_message(%{type: "Change", data: data}, state) do
      %{state | test: data}
    end
  end

  defmodule MessageStoreStreamForwardFake do
    @moduledoc false

    def stream_forward(stream_name) do
      send(self(), {:stream_forward, stream_name})

      [1, 2, 3, 4]
    end
  end

  defmodule MessageStoreStreamForwardErrorFake do
    @moduledoc false

    def stream_forward(stream_name) do
      send(self(), {:stream_forward_error, stream_name})

      {:error, :reason}
    end
  end

  test "fetch/4 should fetch messages from store and project" do
    {:ok, %{}} = MessageStore.fetch("test-12345", TestProjection, &read/1, &project/2)

    assert_received {:read, "test-12345"}
    assert_received {:project, [], TestProjection}
  end

  test "project/2 should return init state of projection if no messages exists" do
    assert MessageStore.project([], TestProjection) == %{test: :init}
  end

  test "project/2 should return correct state" do
    messages = [
      %{type: "Change", data: :changed}
    ]

    assert MessageStore.project(messages, TestProjection) == %{test: :changed}
  end

  test "to_result/2 should convert simple :ok atom to result tuple" do
    assert MessageStore.to_result(:ok, :test) == {:ok, :test}
  end

  test "to_result/2 should pass error tuple" do
    assert MessageStore.to_result({:error, :reason}, :test) == {:error, :reason}
  end

  test "stream_name_to_id/1 - should return id from stream name" do
    assert MessageStore.stream_name_to_id("test-123456") == "123456"
    assert MessageStore.stream_name_to_id("test-12-3456") == "12-3456"
    assert MessageStore.stream_name_to_id("test") == "test"
    assert MessageStore.stream_name_to_id("test-") == ""
  end

  test "expected_version/2 should return result with expected version" do
    result = MessageStore.expected_version(MessageStoreStreamForwardFake, "test-12345")

    assert_received {:stream_forward, "test-12345"}
    assert result == {:ok, 4}
  end

  test "expected_version/2 should return result with error" do
    result = MessageStore.expected_version(MessageStoreStreamForwardErrorFake, "test-12345")

    assert_received {:stream_forward_error, "test-12345"}
    assert result == {:error, :reason}
  end

  defp read(stream_name) do
    send(self(), {:read, stream_name})

    {:ok, []}
  end

  defp project(messages, projection) do
    send(self(), {:project, messages, projection})

    %{}
  end
end
