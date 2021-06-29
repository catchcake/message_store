defmodule MessageStore.Projection do
  @moduledoc """
  A projection boilerplate and helpers.
  """

  @type fetch() :: (String.t(), module() -> Result.t(term(), any()))

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

  @spec load(String.t(), module(), fetch(), (any() -> any())) :: any()
  def load(stream, projection, fetch, fun)
      when is_binary(stream) and is_atom(projection) and is_function(fetch, 2) and
             is_function(fun, 1) do
    {:ok, data} = fetch.(stream, projection)

    fun.(data)
  end
end
