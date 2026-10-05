defmodule Tauros.Authority do
  @moduledoc """
  Which actions an agent may ever be offered, written down once.

  This module enforces nothing. Ash policies enforce authority. It is the
  reviewed list that tests hold the policies to, and the list Epic 4's AshAI
  tool allowlist will be checked against:

    * `agent_safe/0`: capability. Reading, proposing, revising, submitting and
      withdrawing one's own proposals, registering and retiring one's own
      destinations. These may become AI tools.
    * `human_only/0`: authority. Approving, rejecting, sending back and
      cancelling financial commitments; managing humans, agents and customers.
      These must never become AI tools, and the policies refuse agents.
    * `internal/0`: actions no actor may call. They run only inside another,
      already authorized action.

  `test/tauros/authority_test.exs` fails if an action of a business resource
  is not classified, or if a policy disagrees with this list.
  """

  alias Tauros.Accounts.{Agent, User}
  alias Tauros.Revenue.{Approval, Customer, Invoice, InvoiceEvent, InvoiceRevision}
  alias Tauros.Revenue.PaymentDestination

  @agent_safe [
    {Customer, :read},
    {PaymentDestination, :read},
    {PaymentDestination, :create},
    {PaymentDestination, :deactivate},
    {Invoice, :read},
    {Invoice, :awaiting_approval},
    {Invoice, :create_draft},
    {Invoice, :revise},
    {Invoice, :submit_for_approval},
    {Invoice, :withdraw},
    {InvoiceRevision, :read},
    {Approval, :read},
    {InvoiceEvent, :read}
  ]

  @human_only [
    {Invoice, :approve},
    {Invoice, :reject},
    {Invoice, :request_changes},
    {Invoice, :cancel},
    {Customer, :create},
    {Customer, :update},
    {Customer, :destroy},
    {Agent, :read},
    {Agent, :create},
    {Agent, :update},
    {Agent, :rotate_api_key},
    {Agent, :destroy},
    {User, :invite},
    {User, :bootstrap_approver}
  ]

  @internal [
    {InvoiceRevision, :create},
    {Approval, :create},
    {InvoiceEvent, :record},
    {PaymentDestination, :supersede}
  ]

  @doc "Actions an agent may run on its own records. Candidates for AI tools."
  def agent_safe, do: @agent_safe

  @doc "Actions only a human may run, including every authority-bearing one."
  def human_only, do: @human_only

  @doc "Actions no actor may call directly."
  def internal, do: @internal

  @doc "Resources whose every action must be classified."
  def business_resources,
    do: [Customer, PaymentDestination, Invoice, InvoiceRevision, Approval, InvoiceEvent, Agent]

  @doc "`:agent_safe`, `:human_only`, `:internal` or `nil` for `{resource, action}`."
  def classify(resource, action) do
    cond do
      {resource, action} in @agent_safe -> :agent_safe
      {resource, action} in @human_only -> :human_only
      {resource, action} in @internal -> :internal
      true -> nil
    end
  end
end
