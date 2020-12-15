defmodule MessageStore do
  @moduledoc """
  A module for interactions with message store
  """

  alias EventStore.RecordedEvent

  defguard is_conn(conn) when is_atom(conn) or is_pid(conn)

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use EventStore, opts

      def fetch(stream_name, projection, opts \\ [])
          when is_binary(stream_name) and is_atom(projection) and is_list(opts) do
        {conn, opts} = parse_fetch_options(opts)

        MessageStore.fetch(conn, stream_name, projection, opts)
      end

      def expected_version(stream_uuid) when is_binary(stream_uuid) do
        MessageStore.expected_version(__MODULE__, stream_uuid)
      end

      defp parse_fetch_options(opts) do
        opts
        |> parse_opts()
        |> put_read_function(opts)
        |> put_project_function(opts)
      end

      defp put_read_function({conn, base}, opts) do
        read = Keyword.get(opts, :read, &MessageStore.Stream.read/3)

        {conn, Keyword.put(base, :read, read)}
      end

      defp put_project_function({conn, base}, opts) do
        project = Keyword.get(opts, :project, &MessageStore.project/2)

        {conn, Keyword.put(base, :project, project)}
      end
    end
  end

  @spec fetch(
          conn,
          String.t(),
          m,
          read: (conn, String.t(), list() -> Result.t(reason, [RecordedEvent.t()])),
          project: ([RecordedEvent.t()], m -> projection)
        ) :: Result.t(reason, projection)
        when conn: module(), m: module(), reason: term(), projection: any()
  def fetch(conn, stream_name, projection, opts)
      when is_conn(conn) and is_binary(stream_name) and is_atom(projection) and is_list(opts) do
    {read, opts} = Keyword.pop!(opts, :read)
    {project, opts} = Keyword.pop!(opts, :project)

    conn
    |> read.(stream_name, opts)
    |> Result.catch_error(:stream_not_found, fn _ -> {:ok, []} end)
    |> Result.map(&project.(&1, projection))
  end

  @spec project([RecordedEvent.t()], module()) :: any()
  def project(messages, projection) when is_list(messages) and is_atom(projection) do
    Enum.reduce(
      messages,
      projection.init(),
      &projection.handle_message/2
    )
  end

  @spec to_result(:ok | {:error, err}, value) :: Result.t(err, value)
        when err: any(), value: any()
  def to_result(:ok, value) do
    {:ok, value}
  end

  def to_result({:error, _err} = error, _value) do
    error
  end

  @spec category(String.t() | nil) :: String.t()
  def category(nil) do
    ""
  end

  def category(stream_name) when is_binary(stream_name) do
    stream_name
    |> String.split("-")
    |> List.first()
  end

  @spec stream_name_to_id(String.t()) :: String.t() | nil
  def stream_name_to_id(stream_name) when is_binary(stream_name) do
    stream_name
    |> String.split("-", parts: 2)
    |> maybe_id()
  end

  @spec expected_version(atom(), String.t()) :: Result.t(term(), integer())
  def expected_version(message_store, stream_uuid)
      when is_atom(message_store) and is_binary(stream_uuid) do
    stream_uuid
    |> message_store.stream_forward()
    |> stream_length()
  end

  defp stream_length({:error, _} = error) do
    error
  end

  defp stream_length(events) do
    events
    |> Enum.to_list()
    |> length()
    |> Result.ok()
  end

  defp maybe_id([_, ""]) do
    nil
  end

  defp maybe_id([_, id]) do
    id
  end

  defp maybe_id(_) do
    nil
  end
end
