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
      Jason.decode!(binary, keys: :atoms)
    end
  end
end
