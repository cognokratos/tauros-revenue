defmodule TaurosWeb.Mcp.ExactNumbers do
  @moduledoc """
  Refuses floating-point numbers in MCP tool arguments.

  The tool schemas declare every amount as a decimal *string*. A client that
  sends a JSON number anyway has already lost precision: the JSON parser turns
  `123456789012345.123456789` into an IEEE float before Tauros sees it. Rather
  than accept a value that may not be what the model wrote, the call is
  refused with an instruction to send a string. Integers are exact and pass.

  This is transport input shaping, not authorization: it never looks at the
  actor. (The JSON:API refuses numbers for decimal fields through its own
  schema validation.)
  """

  @doc "AshAI `tool_argument_transformer`: `{:ok, arguments}` or `{:error, message}`."
  def reject_floats(_tool, arguments, _context) do
    case find_float(arguments, []) do
      nil ->
        {:ok, arguments}

      path ->
        {:error,
         "#{Enum.join(path, ".")}: send amounts as decimal strings (e.g. \"1200.50\"); " <>
           "Tauros never accepts floating-point numbers"}
    end
  end

  defp find_float(value, path) when is_float(value), do: Enum.reverse(path)

  defp find_float(map, path) when is_map(map),
    do: Enum.find_value(map, fn {key, value} -> find_float(value, [to_string(key) | path]) end)

  defp find_float(list, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.find_value(fn {value, index} -> find_float(value, [to_string(index) | path]) end)
  end

  defp find_float(_value, _path), do: nil
end
