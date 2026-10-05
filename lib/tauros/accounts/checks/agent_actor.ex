defmodule Tauros.Accounts.Checks.AgentActor do
  @moduledoc "Authorizes when the actor is an agent (an AI or service principal authenticated by API key)."
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is an agent"

  @impl true
  def match?(actor, _context, _opts), do: is_struct(actor, Tauros.Accounts.Agent)
end
