defmodule TaurosWeb.Api.Agent.ErrorJSON do
  @moduledoc """
  Error response handler for agent API.
  """

  def error(%{message: message}) do
    %{
      error: %{
        code: "validation_error",
        message: message,
        details: []
      }
    }
  end

  def changeset_errors(%{changeset: changeset}) do
    errors =
      changeset.errors
      |> Enum.map(fn {field, {msg, opts}} ->
        %{field: field, message: interpolate(msg, opts)}
      end)

    %{
      error: %{
        code: "validation_error",
        message: "Validation failed",
        details: errors
      }
    }
  end

  defp interpolate(msg, opts) do
    Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
      opts[String.to_atom(key)] |> to_string()
    end)
  end
end
