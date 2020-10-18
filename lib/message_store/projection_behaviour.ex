defmodule MessageStore.ProjectionBehaviour do
  @moduledoc """
  Projection behaviour.
  """

  alias EventStore.RecordedEvent

  @doc """
  The projection initial state.
  """
  @callback init() :: any()

  @doc """
  A message handler
  """
  @callback handle_message(RecordedEvent.t(), state) :: state when state: any()
end
