defmodule MessageStore.MessageHandler do
  @moduledoc """
  A message handler boilerplate.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour MessageStore.MessageHandlerBehaviour

      alias EventStore.RecordedEvent

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # default handler
      @impl true
      def handle_message(_, _), do: {:ok, nil}
    end
  end
end
