defmodule MessageStore.ProjectionBehaviour do
  @moduledoc """
  Projection behaviour.
  """

  alias EventStore.RecordedEvent

  @doc """
  The projection initial state.
  """
  @callback init() :: map()

  @doc """
  A message handler
  """
  @callback handle_message(RecordedEvent.t(), map()) :: map()
end
