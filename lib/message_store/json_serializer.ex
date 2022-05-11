if Code.ensure_loaded?(Jason) do
  defmodule MessageStore.JsonSerializer do
    @moduledoc """
    A serializer that uses the JSON format.
    """

    @behaviour EventStore.Serializer

    @doc """
    Serialize given term to JSON binary data.
    """
    def serialize(term) do
      Jason.encode!(term)
    end

    @doc """
    Deserialize given JSON binary data to the expected type.
    """
    def deserialize(binary, _config) do
      keys_setting = get_keys_setting()

      Jason.decode!(binary, keys: keys_setting)
    end

    defp get_keys_setting() do
      :message_store
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:keys, :atoms!)
    end
  end
end
