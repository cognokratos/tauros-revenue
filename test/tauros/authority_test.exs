defmodule Tauros.AuthorityTest do
  @moduledoc """
  The executable authority invariant. `Tauros.Authority` lists which actions
  are agent-safe, human-only or internal. These tests hold every business
  action to that list, and the policies to it, against real records:

    * every action is classified, so a new action cannot slip in unreviewed
    * an agent is refused every human-only action on its own owner's records
    * the owning agent is allowed every agent-safe action
    * no actor at all may call an internal action

  Epic 4 adds one more: every AshAI tool must be in `Tauros.Authority.agent_safe/0`.
  """
  use Tauros.DataCase, async: true

  alias Tauros.Accounts.{Agent, User}
  alias Tauros.Authority
  alias Tauros.Revenue
  alias Tauros.Revenue.{Customer, Invoice}
  alias Tauros.Revenue.PaymentDestination

  setup do
    approver = approver()
    agent = agent(approver)
    customer = customer(agent)
    destination = payment_destination(agent)

    pending =
      agent
      |> invoice_draft(customer: customer, destination: destination)
      |> Revenue.submit_invoice!(actor: agent)

    draft = invoice_draft(agent, customer: customer, destination: destination)
    revision = Ash.load!(pending, :current_revision, authorize?: false).current_revision

    %{
      approver: approver,
      agent: agent,
      customer: customer,
      destination: destination,
      pending: pending,
      draft: draft,
      revision: revision,
      decision: %{revision_id: revision.id, payload_hash: revision.payload_hash, reason: "r"}
    }
  end

  # The subject `Ash.can?/3` checks for each action, built from the agent's own world.
  defp subject(ctx, Invoice, action) when action in [:approve, :reject, :request_changes],
    do: {ctx.pending, action, ctx.decision}

  defp subject(ctx, Invoice, :cancel), do: {ctx.pending, :cancel, %{reason: "r"}}
  defp subject(ctx, Invoice, :create_draft), do: {Invoice, :create_draft, draft_input(ctx.agent)}
  defp subject(ctx, Invoice, :revise), do: {ctx.draft, :revise, %{reasoning: "r"}}
  defp subject(ctx, Invoice, action), do: {ctx.draft, action}

  defp subject(ctx, Customer, :create),
    do: {Customer, :create, %{name: "n", email: "a@b.c", agent_id: ctx.agent.id}}

  defp subject(ctx, Customer, action), do: {ctx.customer, action}

  defp subject(_ctx, PaymentDestination, :create),
    do: {PaymentDestination, :create, %{label: "l"}}

  defp subject(ctx, PaymentDestination, action), do: {ctx.destination, action}
  defp subject(_ctx, Agent, :create), do: {Agent, :create, %{name: "n"}}
  defp subject(ctx, Agent, action), do: {ctx.agent, action}

  defp subject(_ctx, User, :invite),
    do: {User, :invite, %{email: "x@example.com", role: :approver}}

  defp subject(_ctx, User, :bootstrap_approver),
    do: {User, :bootstrap_approver, %{email: "x@example.com"}}

  defp subject(_ctx, resource, action), do: {resource, action}

  defp can?(ctx, {resource, action}, actor),
    do: Ash.can?(subject(ctx, resource, action), actor, maybe_is: false, run_queries?: true)

  defp reads_nothing?(resource, action, actor),
    do: resource |> Ash.Query.for_read(action, %{}, actor: actor) |> Ash.read() |> nothing?()

  defp nothing?({:ok, []}), do: true
  defp nothing?({:error, %Ash.Error.Forbidden{}}), do: true
  defp nothing?(_), do: false

  test "every action of every business resource is classified exactly once" do
    lists = Authority.agent_safe() ++ Authority.human_only() ++ Authority.internal()
    assert lists == Enum.uniq(lists), "an action is classified twice"

    for resource <- Authority.business_resources(),
        action <- Ash.Resource.Info.actions(resource),
        # AshAuthentication's own plumbing, guarded by its interaction bypass.
        {resource, action.name} not in [
          {Agent, :sign_in_with_api_key},
          {Agent, :get_by_subject}
        ] do
      assert Authority.classify(resource, action.name),
             "#{inspect(resource)}.#{action.name} is not classified in Tauros.Authority"
    end
  end

  test "an agent is refused every human-only action, even on its owner's records", ctx do
    for {resource, action} = entry <- Authority.human_only() do
      refused? =
        if Ash.Resource.Info.action(resource, action).type == :read,
          do: reads_nothing?(resource, action, ctx.agent),
          else: not can?(ctx, entry, ctx.agent)

      assert refused?, "agent was allowed #{inspect(resource)}.#{action}"
    end
  end

  test "the owning agent may run every agent-safe action", ctx do
    for {resource, action} = entry <- Authority.agent_safe() do
      allowed? =
        if Ash.Resource.Info.action(resource, action).type == :read,
          do:
            match?(
              {:ok, _},
              resource |> Ash.Query.for_read(action, %{}, actor: ctx.agent) |> Ash.read()
            ),
          else: can?(ctx, entry, ctx.agent)

      assert allowed?, "agent was refused #{inspect(resource)}.#{action}"
    end
  end

  test "the owning approver holds the authority the agent lacks", ctx do
    for entry <- [
          {Invoice, :approve},
          {Invoice, :reject},
          {Invoice, :request_changes},
          {User, :invite}
        ] do
      assert can?(ctx, entry, ctx.approver), "approver was refused #{inspect(entry)}"
    end
  end

  test "no actor may call an internal action", ctx do
    for {resource, action} <- Authority.internal(), actor <- [ctx.agent, ctx.approver] do
      refute can?(ctx, {resource, action}, actor),
             "#{inspect(actor.__struct__)} was allowed #{inspect(resource)}.#{action}"
    end
  end
end
