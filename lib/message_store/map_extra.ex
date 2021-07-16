defmodule MessageStore.MapExtra do
  @moduledoc """
  An extra functions for Map data type.
  """

  defmodule PathError do
    defexception [:path, :term, :message]

    @impl true
    def message(%{message: nil} = exception), do: message(exception.path, exception.term)
    def message(%{message: message}), do: message

    defp message(path, term) do
      message = "path #{inspect(path)} not found"

      if term != nil do
        message <> " in: #{inspect(term)}"
      else
        message
      end
    end
  end

  @doc """
  Fetches the value for a specific `path` in the given `map`.

  If `map` contains the given `path` then its value is returned in the shape of `{:ok, value}`.
  If `map` doesn't contain `path`, :error is returned.

  ## Examples
      iex> a = %{a: 1, b: %{c: 2}}
      iex> MapExtra.fetch_in(a, [:a])
      {:ok, 1}

      iex> a = %{a: 1, b: %{c: 2}}
      iex> MapExtra.fetch_in(a, [:b, :c])
      {:ok, 2}

      iex> a = %{a: 1, b: %{c: 2}}
      iex> MapExtra.fetch_in(a, [:b, :d])
      :error
  """
  @spec fetch_in(map(), [Map.key()]) :: {:ok, Map.value()} | :error
  def fetch_in(map, path) when is_map(map) and is_list(path) do
    fetch({:ok, map}, path)
  end

  defp fetch(result, []), do: result
  defp fetch(:error, _), do: :error

  defp fetch({:ok, map}, [key | rest_path]) when is_map(map) do
    map
    |> Map.fetch(key)
    |> fetch(rest_path)
  end

  @doc """
  Fetches the value for a specific `path` in the given map, erroring out if map doesn't contain `path`.

  If map contains `path`, the corresponding value is returned.
  If map doesn't contain `path`, a `PathError` exception is raised.

  ## Examples
      iex> a = %{a: 1, b: %{c: 2}}
      iex> MapExtra.fetch_in!(a, [:a])
      1
  """
  @spec fetch_in!(map(), [Map.key()]) :: Map.value()
  def fetch_in!(map, path) do
    case fetch_in(map, path) do
      {:ok, value} -> value
      :error -> raise(PathError, path: path, term: map)
    end
  end
end
