defmodule MessageStore.Subscriber do
  @moduledoc """
  A subscribe server for handling messages.

  ## Options

  * `message_store: module` - it's messages store module for access event data/streams. Required.
  * `stream_name: string` - it's stream name to subscribe for messages. Required.
  * `handlers: module` - message handlers. Required.
  * `subscriber_name: string` - unique name. Required.
  * `origin_stream_name: string` - when is set, filter messages that has in metadata same value in `origin_stream_name` key. Optional.
  * `address: string` - used for filter messages with same value in metadata `recipient` key. Optional.
  * `event_store_name: string` the name of the event store if provided to `EventStore.start_link/1`.
  * `start_from: atom` is a pointer to the first event to receive.
    It must be one of:
      - `:origin` for all events from the start of the stream (default).
      - `:current` for any new events appended to the stream after the
        subscription has been created.
      - any positive integer for a stream version to receive events after.
  * `buffer_size: integer` limits how many in-flight events will be sent to the
    subscriber process before acknowledgement of successful processing. This
    limits the number of messages sent to the subscriber and stops their
    message queue from getting filled with events. Defaults to one in-flight
    event.
  * `transient: boolean` is an optional boolean flag to create a transient subscription.
    By default this is set to `false`. If you want to create a transient
    subscription set this flag to true. Your subscription will not be
    persisted, so if the subscription is restarted, you will receive the events
    again starting from `start_from`.
    An example usage are short lived event handlers that keep their state in
    memory but still want to have the guarantee to have received all events.
    It's possible to create a persistent subscription with some name,
    stop it and later create a transient subscription with the same name. The
    transient subscription will now receive all events starting from `start_from`.
    If you later stop this `transient` subscription and start a persistent
    subscription again with the same name, you will receive the events again
    as if the transient subscription never existed.
  """
  use GenServer

  alias EventStore.RecordedEvent

  require Logger

  # Server

  def child_spec(%{subscriber_name: subscriber_name} = args) do
    %{
      id: String.to_atom(subscriber_name),
      start: {__MODULE__, :start_link, [args]}
    }
  end

  @doc false
  def start_link(
        %{
          message_store: message_store,
          stream_name: stream_name,
          handlers: handlers,
          subscriber_name: subscriber_name
        } = settings
      )
      when is_binary(stream_name) and is_binary(subscriber_name) and is_atom(handlers) and
             is_atom(message_store) do
    Logger.info(fn -> "Starting #{subscriber_name} subscriber..." end)
    GenServer.start_link(__MODULE__, settings, name: String.to_atom(subscriber_name))
  end

  @impl true
  def init(settings) do
    {:ok, _subscription} =
      settings.message_store.subscribe_to_all_streams(
        settings.subscriber_name,
        self(),
        eventstore_opts(settings)
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
    messages_count = Enum.count(messages)

    messages
    |> process_message_batch(settings)
    |> ack_messages(settings)
    |> log_processed_messages(messages_count, settings)
    |> exit_or_continue(messages_count, settings)
  end

  # Private

  defp process_message_batch(messages, settings) do
    messages
    |> Enum.reduce_while([], &process_message(&1, &2, settings))
    |> Enum.reverse()
  end

  defp process_message(message, acc, settings) do
    message
    |> settings.handlers.handle_message(settings)
    |> log_error(settings)
    |> halt_or_continue(message, acc)
  end

  defp halt_or_continue({:error, _}, _message, acc) do
    {:halt, acc}
  end

  defp halt_or_continue({:ok, _}, message, acc) do
    {:cont, [message | acc]}
  end

  defp ack_messages([], _settings) do
    {:ok, 0}
  end

  defp ack_messages(messages, settings) do
    case settings.message_store.ack(settings.subscription, messages) do
      :ok -> {:ok, Enum.count(messages)}
      error -> error
    end
  end

  defp exit_or_continue({:ok, count}, original_count, settings) when count == original_count do
    {:noreply, settings}
  end

  defp exit_or_continue({:ok, _count}, _original_count, settings) do
    {:stop, :error_in_message_processing, settings}
  end

  defp exit_or_continue({:error, _msg}, _original_count, settings) do
    Logger.info(fn -> "Subscriber #{settings.subscriber_name} shutting down..." end)
    {:stop, :shutdown, settings}
  end

  defp log_error({:error, err} = result, settings) do
    Logger.error(fn ->
      "Subscriber #{settings.subscriber_name} ended with #{inspect(err)} error..."
    end)

    result
  end

  defp log_error(result, _settings) do
    result
  end

  defp log_processed_messages({:ok, count} = result, original_count, settings)
       when count == original_count do
    Logger.debug(fn -> "Subscriber #{settings.subscriber_name} processed #{count} messages..." end)

    result
  end

  defp log_processed_messages({:ok, count} = result, original_count, settings) do
    Logger.error(fn ->
      "Subscriber #{settings.subscriber_name} processed #{count} messages instead #{
        original_count
      } messages."
    end)

    result
  end

  defp log_processed_messages(result, _original_count, settings) do
    log_error(result, settings)
  end

  defp selector(settings, %RecordedEvent{} = message) when is_map(settings) do
    [
      settings |> Map.fetch!(:stream_name) |> stream_uuid_selector(message),
      settings |> Map.get(:origin_stream_name, nil) |> origin_stream_name_selector(message),
      settings |> Map.get(:address, nil) |> recipient_selector(message)
    ]
    |> Enum.all?()
  end

  defp origin_stream_name_selector(nil, _message) do
    true
  end

  defp origin_stream_name_selector(origin_stream_name, %RecordedEvent{metadata: metadata})
       when is_binary(origin_stream_name) and origin_stream_name != "" and is_map(metadata) do
    message_origin_stream_name = Map.get(metadata, :origin_stream_name)

    MessageStore.category(message_origin_stream_name) == origin_stream_name
  end

  defp stream_uuid_selector(stream_name, %RecordedEvent{stream_uuid: stream_uuid})
       when is_binary(stream_name) and is_binary(stream_uuid) do
    MessageStore.category(stream_uuid) == stream_name
  end

  defp recipient_selector(nil, _message) do
    true
  end

  defp recipient_selector(address, %RecordedEvent{
         metadata: metadata
       })
       when is_binary(address) and is_map(metadata) do
    recipient = Map.get(metadata, :recipient)

    address == recipient
  end

  defp eventstore_opts(settings) when is_map(settings) do
    settings
    |> Map.take([
      :event_store_name,
      :start_from,
      :buffer_size,
      :transient
    ])
    |> rename_key(:event_store_name, :name)
    |> Keyword.new()
    |> Keyword.put(:selector, &selector(settings, &1))
  end

  defp rename_key(map, current_key, new_key) when is_map(map) do
    map
    |> Map.pop(current_key)
    |> put_value_with_new_key(new_key)
  end

  defp put_value_with_new_key({nil, map}, _new_key), do: map
  defp put_value_with_new_key({value, map}, new_key), do: Map.put(map, new_key, value)
end
