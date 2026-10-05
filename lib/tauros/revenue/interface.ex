defmodule Tauros.Revenue.Interface do
  @moduledoc """
  Which interface a command arrived through. It is recorded for audit only and
  never consulted for authorization: Ash policies decide the same way
  whichever interface is used.
  """
  use Ash.Type.Enum,
    values: [
      ui: "The LiveView UI",
      api: "The JSON:API (REST)",
      mcp: "The MCP endpoint (AshAI tools), always as an agent",
      console: "A direct Ash call: console, seeds, tests or a job"
    ]
end
