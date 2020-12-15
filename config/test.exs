use Mix.Config

eventstore_url =
  System.get_env("EVENTSTORE_URL") ||
    raise("A EVENTSTORE_URL environment variable must be set!!!")

config(:message_store, TestMessageStore,
  url: eventstore_url,
  serializer: MessageStore.JsonSerializer,
  column_data_type: "jsonb",
  types: EventStore.PostgresTypes
)

config(:message_store, event_stores: [TestMessageStore])
