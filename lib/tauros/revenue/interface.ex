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
      console: "A direct Ash call: console, seeds, tests or a job"
    ]
end
