defmodule MessageStore.Subscriber do
  @moduledoc """
  A subscribe server for handling messages.
  """
  use GenServer

  alias EventStore.RecordedEvent

  require Logger

  # Server

  @doc false
  def start_link(
        %{
          message_store: message_store,
          repo: repo,
          stream_name: stream_name,
          handlers: handlers,
          subscriber_name: subscriber_name
        } = settings
      )
      when is_binary(stream_name) and is_binary(subscriber_name) and is_atom(handlers) and
             is_atom(message_store) and is_atom(repo) do
    Logger.info(fn -> "Starting #{subscriber_name} subscriber..." end)
    GenServer.start_link(__MODULE__, settings)
  end

  @impl true
  def init(state) do
    {:ok, _subscription} =
      state.message_store.subscribe_to_all_streams(
        state.subscriber_name,
        self(),
        selector: fn %RecordedEvent{stream_uuid: stream_uuid} ->
          String.starts_with?(stream_uuid, "#{state.stream_name}-")
        end
      )

    {:ok, state}
  end

  @impl true
  def handle_info({:subscribed, subscription}, state) do
    Logger.info(fn -> "Subscribed to #{state.stream_name} as #{state.subscriber_name}" end)

    {:noreply, Map.put(state, :subscription, subscription)}
  end

  @impl true
  def handle_info({:events, messages}, state) do
    messages
    |> Result.ok()
    |> process_message_batch(state)
    |> Result.map(fn _ -> Enum.count(messages) end)
    |> log(state)

    {:noreply, state}
  end

  # Private

  defp process_message_batch({:ok, [message | rest]}, state) do
    message
    |> state.handlers.handle_message(%{message_store: state.message_store, repo: state.repo})
    |> Result.and_then(&ack(&1, state.message_store, message, state.subscription))
    |> Result.map(fn _ -> rest end)
    |> process_message_batch(state)
  end

  defp process_message_batch(result, _state) do
    result
  end

  defp ack(value, message_store, message, subscription) do
    case message_store.ack(subscription, message) do
      :ok -> {:ok, value}
      error -> error
    end
  end

  defp log({:ok, count}, state) do
    Logger.debug(fn -> "Subscriber #{state.subscriber_name} processed #{count} messages..." end)
  end

  defp log({:error, err}, state) do
    Logger.error(fn ->
      "Subscriber #{state.subscriber_name} ended with #{inspect(err)} error..."
    end)
  end
end
