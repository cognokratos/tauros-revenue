defmodule Tauros.Accounts.Checks.NoApproverYet do
  @moduledoc """
  Authorizes only while no human holds approval authority. This is how the
  first approver comes into existence without open registration, on a fresh
  installation or on one upgraded from before roles existed.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts), do: "no human approver exists yet"

  @impl true
  def match?(_actor, _context, _opts) do
    not (Tauros.Accounts.User
         |> Ash.Query.filter(role == :approver)
         |> Ash.exists?(authorize?: false))
  end
end
