defmodule MessageStore.Projection do
  @moduledoc """
  A projection boilerplate.
  """

  defmacro __using__(_env) do
    quote do
      @behaviour MessageStore.ProjectionBehaviour

      alias EventStore.RecordedEvent

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # default handler when unknown event arrived
      def handle_message(_, data), do: data
    end
  end
end
