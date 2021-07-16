defmodule MessageStore.Message do
  @moduledoc """
  A module for build, copy and folow message data.
  """

  alias EventStore.{EventData, RecordedEvent}
  alias ExMaybe, as: Maybe
  alias MessageStore.MapExtra

  @type uuid() :: String.t()
  @type message_type :: String.t() | atom()
  @type message() :: %{
          optional(:event_id) => uuid(),
          required(:type) => message_type(),
          required(:data) => map(),
          required(:metadata) => map(),
          optional(:causation_id) => uuid(),
          optional(:correlation_id) => uuid()
        }
  @type event_message() :: EventData.t()
  @type recorded_message() :: RecordedEvent.t()
  @type stream_name() :: String.t()
  @type version() :: EventStore.expected_version()
  @type key() :: Map.key()
  @type path() :: nonempty_list(key())

  defguard is_data_or_metadata(d) when d in [:data, :metadata]
  defguard is_version(version) when is_atom(version) or (is_integer(version) and version >= 0)
  defguard is_module_name(module) when is_atom(module) and module not in [nil, true, false]
  defguard is_message_type(type) when is_atom(type) or is_binary(type)

  @doc """
  Create event data struct from message map.

  ## Examples
      iex> message = %{type: "Foo", data: %{foo: 1}, metadata: %{bar: 2}}
      iex> Message.build(message)
      %EventStore.EventData{
        event_id: nil,
        event_type: "Foo",
        data: %{foo: 1},
        metadata: %{bar: 2},
        causation_id: nil,
        correlation_id: nil
      }
  """
  @spec build(message()) :: event_message()
  def build(message) when is_map(message) do
    %EventData{
      event_id: Map.get(message, :event_id),
      event_type: message |> Map.fetch!(:type) |> to_string(),
      data: Map.fetch!(message, :data),
      metadata: Map.fetch!(message, :metadata),
      causation_id: Map.get(message, :causation_id, nil),
      correlation_id: Map.get(message, :correlation_id, nil)
    }
  end

  @doc """
  The copy function constructs a message from another message's data.

  ## Examples
      iex> recorded_message = %EventStore.RecordedEvent{
      ...> causation_id: nil,
      ...> correlation_id: "abcd1234",
      ...> created_at: ~U[2021-07-15 12:15:07.379908Z],
      ...> data: %{foo: "bazinga"},
      ...> event_id: "b9fcdccd-a495-4df3-889a-4b38f35a2618",
      ...> event_number: 935,
      ...> event_type: "Test",
      ...> metadata: %{bar: "baz", moo: 1},
      ...> stream_uuid: "test-123",
      ...> stream_version: 935
      ...> }
      iex> Message.copy("Foo", recorded_message, [:data, [:metadata, :bar]])
      %EventStore.EventData{
        event_id: nil,
        event_type: "Foo",
        data: %{foo: "bazinga"},
        metadata: %{bar: "baz"},
        causation_id: nil,
        correlation_id: nil
      }

  <div style="background-color: rgba(255,229,100,.3); border-color: #e7c000; color: #6b5900; padding: .1rem 1.5rem; border-left-width: .5rem; border-left-style: solid; margin: 1rem 0;">
    <h2>Warning</h2>

    <p>Copying the metadata should be used with extreme caution, and has no practical use in everyday applicative logic.
    Except for certain testing and infrastructural scenarios,
    copying the identifying metadata from one message to another can result in significant malfunctions
    if the copied message is then written to a stream and processed.</p>
  </div>
  """
  @spec copy(message_type(), recorded_message(), [path() | key()]) :: event_message()
  def copy(type, recorded_message, copy_list)
      when is_message_type(type) and is_map(recorded_message) and is_list(copy_list) do
    copy_list
    |> Enum.map(&get_data_from(&1, recorded_message))
    |> Enum.reduce(type |> new() |> build(), &update_message(&1, &2))
  end

  @doc """
  Constructing a message from a preceding message.

  Following a message has almost identical behavior to a message `copy/3` method.
  The follow message leverages the implementation of `copy/3` to fulfill its purpose.

  ## Message Workflows

  Messages frequently represent subsequent steps or stages in a process.
  Subsequent messages follow after preceding messages.
  Selected data or metadata from the preceding message is copied to the subsequent messages.

  ## Examples
      iex> recorded_message = %EventStore.RecordedEvent{
      ...> causation_id: nil,
      ...> correlation_id: "abcd1234",
      ...> created_at: ~U[2021-07-15 12:15:07.379908Z],
      ...> data: %{foo: "bazinga"},
      ...> event_id: "b9fcdccd-a495-4df3-889a-4b38f35a2618",
      ...> event_number: 935,
      ...> event_type: "Test",
      ...> metadata: %{bar: "baz", moo: 1},
      ...> stream_uuid: "test-123",
      ...> stream_version: 935
      ...> }
      iex> Message.follow("Foo", recorded_message, [:data, [:metadata, :bar]])
      %EventStore.EventData{
        event_id: nil,
        event_type: "Foo",
        data: %{foo: "bazinga"},
        metadata: %{bar: "baz"},
        causation_id: "b9fcdccd-a495-4df3-889a-4b38f35a2618",
        correlation_id: "abcd1234"
      }
  """
  @spec follow(message_type(), recorded_message(), [path() | key()]) :: event_message()
  def follow(type, recorded_message, copy_list)
      when is_message_type(type) and is_map(recorded_message) and is_list(copy_list) do
    type
    |> copy(recorded_message, copy_list)
    |> Map.put(
      :correlation_id,
      recorded_message.correlation_id |> Maybe.with_default(recorded_message.event_id)
    )
    |> Map.put(:causation_id, recorded_message.event_id)
  end

  @spec type_from_module(module()) :: String.t()
  def type_from_module(module) when is_module_name(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
  end

  @spec write(module(), stream_name(), event_message() | [event_message()], version()) ::
          Result.t(any(), any())
  def write(message_store, stream_name, message_or_messages, version \\ :any_version)

  def write(message_store, stream_name, messages, version)
      when is_atom(message_store) and is_binary(stream_name) and is_list(messages) and
             is_version(version) do
    stream_name
    |> message_store.append_to_stream(version, messages)
    |> MessageStore.to_result(stream_name)
  end

  def write(message_store, stream_name, message, version)
      when is_atom(message_store) and is_binary(stream_name) and is_map(message) and
             is_version(version),
      do: write(message_store, stream_name, [message], version)

  # Private

  defp get_data_from(path, map) when is_list(path) and is_map(map) do
    {path, MapExtra.fetch_in!(map, path)}
  end

  defp get_data_from(key, map) when is_map_key(map, key) do
    get_data_from([key], map)
  end

  defp update_message({path, value}, message) when is_list(path) and is_map(message) do
    put_in(message, path, value)
  end

  defp new(type) do
    %{
      type: type,
      data: %{},
      metadata: %{}
    }
  end
end
