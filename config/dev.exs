use Mix.Config

eventstore_url = "#{System.fetch_env!("EVENTSTORE_URL")}"

config(:message_store, TestMessageStore,
  url: eventstore_url,
  serializer: MessageStore.JsonSerializer,
  column_data_type: "jsonb",
  types: EventStore.PostgresTypes
)

config(:message_store, event_stores: [TestMessageStore])
