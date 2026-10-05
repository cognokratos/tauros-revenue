defmodule Tauros.Accounts.Checks.HumanActor do
  @moduledoc "Authorizes when the actor is a human user (signed in through the UI or a bearer token)."
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is a human user"

  @impl true
  def match?(actor, _context, _opts), do: is_struct(actor, Tauros.Accounts.User)
end
