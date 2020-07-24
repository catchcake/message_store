defmodule MessageStore.MessageHandlerBehaviour do
  @moduledoc """
  Subscriber message handler behaviour.
  """

  alias EventStore.RecordedEvent

  @doc """
  A message handler.
  """
  @callback handle_message(RecordedEvent.t(), map()) :: Result.t(any(), any())
end
