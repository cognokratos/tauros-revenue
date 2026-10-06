defmodule TaurosWeb.Mcp.StrictArguments do
  @moduledoc """
  The MCP argument boundary: a tool call must express exactly the command
  Tauros declares.

  Run by AshAI (`tool_argument_transformer`) before every tool call, for every
  tool, it refuses:

    * **unknown top-level arguments.** The accepted names are read from the
      same input schema `tools/list` publishes (`AshAi.Tools.parameter_schema/2`),
      so the check can never drift from what the model was shown. (Unknown
      keys *inside* `input` are refused by AshAI itself.)
    * **floating-point numbers anywhere.** The schemas declare amounts as
      decimal strings; a JSON number has already been parsed into an IEEE
      float, so it may not be what the model wrote. Integers are exact and pass.

  This is transport input shaping, not authorization: it never looks at the
  actor. Policies decide what the agent may do.
  """

  @doc "AshAI `tool_argument_transformer`: `{:ok, arguments}` or `{:error, message}`."
  def check(tool, arguments, _context) do
    with :ok <- known_arguments(tool, arguments),
         :ok <- no_floats(arguments) do
      {:ok, arguments}
    end
  end

  defp known_arguments(tool, arguments) do
    accepted =
      tool
      |> AshAi.Tools.parameter_schema(strict: false)
      |> properties()
      |> Map.keys()
      |> Enum.map(&to_string/1)
      |> Enum.sort()

    case arguments
         |> Map.keys()
         |> Enum.map(&to_string/1)
         |> Enum.reject(&(&1 in accepted))
         |> Enum.sort() do
      [] ->
        :ok

      unknown ->
        {:error,
         "Unknown arguments for #{tool.name}: #{Enum.join(unknown, ", ")}. " <>
           "Accepted arguments: #{Enum.join(accepted, ", ")}"}
    end
  end

  defp properties(schema), do: schema[:properties] || schema["properties"] || %{}

  defp no_floats(arguments) do
    case find_float(arguments, []) do
      nil ->
        :ok

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
