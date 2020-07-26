use Mix.Config

#     config(:message_store, key: :value)
#
# And access this configuration in your application as:
#
#     Application.get_env(:message_store, :key)
#
# Or configure a 3rd-party app:
#
#     config(:logger, level: :info)
#

# eventstore_url =
#   System.get_env("EVENTSTORE_URL") ||
#     raise("A EVENTSTORE_URL environment variable must be set!!!")

# config(:message_store, MessageStore,
#   url: eventstore_url,
#   serializer: MessageStore.JsonSerializer,
#   column_data_type: "jsonb",
#   types: EventStore.PostgresTypes
# )

# config(:message_store, event_stores: [MessageStore])
# Example per-environment config:
#
#     import_config("#{Mix.env}.exs")
