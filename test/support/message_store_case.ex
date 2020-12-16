defmodule MessageStoreCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection and database.
  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias EventStore.{Config, Storage}

  @event_store TestMessageStore

  using do
    quote do
      # Import conveniences for testing with connections
      use ExUnit.Case
    end
  end

  setup_all do
    config = Config.parsed(@event_store, :message_store)
    postgrex_config = Config.default_postgrex_opts(config)

    conn = start_supervised!({Postgrex, postgrex_config})

    [
      conn: conn,
      config: config,
      schema: "public",
      event_store: @event_store,
      postgrex_config: postgrex_config
    ]
  end

  setup %{conn: conn, config: config} = context do
    if context[:async] do
      raise "Testing with the database cannot be asynchronous!!!"
    end

    Storage.Initializer.reset!(conn, config)

    start_supervised!(@event_store)

    opts = Config.lookup(@event_store)
    conn = Keyword.fetch!(opts, :conn)

    {:ok, conn: conn, opts: opts}
  end
end
