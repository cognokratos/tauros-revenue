defmodule Tauros.Accounts.Checks.HumanApprover do
  @moduledoc """
  Authorizes when the actor is a human user holding approval authority
  (`role: :approver`). An agent never matches, whatever it is asked to do.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is a human approver"

  @impl true
  def match?(%Tauros.Accounts.User{role: :approver}, _context, _opts), do: true
  def match?(_actor, _context, _opts), do: false
end
