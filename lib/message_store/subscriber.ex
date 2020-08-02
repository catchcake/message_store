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
    GenServer.start_link(__MODULE__, settings, name: String.to_atom(subscriber_name))
  end

  @impl true
  def init(settings) do
    {:ok, _subscription} =
      settings.message_store.subscribe_to_all_streams(
        settings.subscriber_name,
        self(),
        selector: make_selector(settings)
      )

    {:ok, settings}
  end

  @impl true
  def handle_info({:subscribed, subscription}, settings) do
    Logger.info(fn -> "Subscribed to #{settings.stream_name} as #{settings.subscriber_name}" end)

    {:noreply, Map.put(settings, :subscription, subscription)}
  end

  @impl true
  def handle_info({:events, messages}, settings) do
    messages
    |> Result.ok()
    |> process_message_batch(settings)
    |> Result.map(fn _ -> Enum.count(messages) end)
    |> log(settings)

    {:noreply, settings}
  end

  # Private

  defp process_message_batch({:ok, [message | rest]}, settings) do
    message
    |> settings.handlers.handle_message(%{
      message_store: settings.message_store,
      repo: settings.repo
    })
    |> Result.and_then(&ack(&1, settings.message_store, message, settings.subscription))
    |> Result.map(fn _ -> rest end)
    |> process_message_batch(settings)
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

  defp log({:ok, count}, settings) do
    Logger.debug(fn -> "Subscriber #{settings.subscriber_name} processed #{count} messages..." end)
  end

  defp log({:error, err}, settings) do
    Logger.error(fn ->
      "Subscriber #{settings.subscriber_name} ended with #{inspect(err)} error..."
    end)
  end

  defp make_selector(%{origin_stream_name: origin_stream_name, stream_name: stream_name}) do
    fn %RecordedEvent{} = message ->
      stream_uuid_selector(stream_name, message) and
        origin_stream_name_selector(origin_stream_name, message)
    end
  end

  defp make_selector(%{stream_name: stream_name}) do
    &stream_uuid_selector(stream_name, &1)
  end

  defp origin_stream_name_selector(origin_stream_name, %RecordedEvent{
         metadata: %{origin_stream_name: message_origin_stream_name}
       })
       when is_binary(origin_stream_name) and is_binary(message_origin_stream_name) do
    MessageStore.category(message_origin_stream_name) == origin_stream_name
  end

  defp stream_uuid_selector(stream_name, %RecordedEvent{stream_uuid: stream_uuid})
       when is_binary(stream_name) and is_binary(stream_uuid) do
    MessageStore.category(stream_uuid) == stream_name
  end
end
