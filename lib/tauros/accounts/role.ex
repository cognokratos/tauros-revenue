defmodule Tauros.Accounts.Role do
  @moduledoc """
  What a human may do with the agents they own.

    * `:operator` manages agents and customers, reviews proposals and payment
      destinations, and can withdraw drafts. An operator cannot approve.
    * `:approver` can do everything an operator can, and also approve, reject
      or send back financial proposals, cancel approved invoices and invite
      other humans.

  Agents have no role. Whatever an agent is allowed to do is a capability; it
  never carries authority. A role is set when a human is invited (or
  bootstrapped) and no action accepts it afterwards.
  """
  use Ash.Type.Enum,
    values: [
      operator: "May operate: manage agents and customers, review proposals",
      approver: "May also approve financial proposals and invite humans"
    ]
end
