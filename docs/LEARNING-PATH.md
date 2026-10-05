# Learning path

A reading order through the repository. Each stop names one idea, the
smallest piece of code that demonstrates it, and a test or exercise that
proves it. Keep one question in mind throughout:

> **What exact line stops an agent with a valid key from doing this?**

By the end you should be able to answer it for approving an invoice, through
the UI, REST or an AI tool, without looking (the answer is in [AI-AUTHORITY.md](AI-AUTHORITY.md#what-exactly-stops-an-agent-from-approving-an-invoice)).

## 1. Capability vs authority

Read [VISION.md](VISION.md), then [AI-AUTHORITY.md](AI-AUTHORITY.md). Then
open `lib/tauros/authority.ex`: the whole application's answer to "what may an
agent do?" fits on one screen. Its test (`test/tauros/authority_test.exs`)
fails if a new action is not classified, or if a policy disagrees.

## 2. Actor identity

Two structs, two kinds of actor: `Tauros.Accounts.User` (a human, with a
`role`) and `Tauros.Accounts.Agent` (an AI or service, with an API key). Read
the three checks in `lib/tauros/accounts/checks/`: `HumanActor`,
`HumanApprover`, `AgentActor`. Then read `lib/tauros_web/api_auth.ex` to see
how one bearer header becomes either kind.

Registration is closed (`registration_enabled? false` in `user.ex`). Find
`bootstrap_approver` and `invite`, and the policies that guard them. Why
does `bootstrap_approver` say `forbid_if AgentActor`?
(`test/tauros/accounts/user_test.exs`)

## 3. Ownership policies

Open `lib/tauros/revenue/customer.ex`. Ownership is a relationship path:
`relates_to_actor_via([:agent, :user])` for humans, `relates_to_actor_via(:agent)`
for agents. Records you cannot see behave as if they don't exist.

*Try:* [exercise 1, break ownership](EXERCISES.md#1-break-ownership).

## 4. Immutable payment destinations

Read [concepts/payment-destinations.md](concepts/payment-destinations.md),
then `lib/tauros/revenue/network.ex` (a currency is not a rail),
`lib/tauros/revenue/address.ex` (format vs checksum) and
`lib/tauros/revenue/payment_destination.ex`: no action can change an address,
but the state machine can retire one.

*Proof:* `test/tauros/revenue/payment_destination_test.exs`, especially
"checksums catch typos that the format alone would accept".

## 5. Financial intent

An agent proposes; the proposal is data, never a fact. Read
`Invoice.create_draft` in `lib/tauros/revenue/invoice.ex` and
`Validations.UsableReferences` in `lib/tauros/revenue/invoice_revision/validations/`.
The caller's ids are never trusted: each record is loaded and compared.

## 6. Invoice revisions

Read [concepts/exact-payload-approval.md](concepts/exact-payload-approval.md),
then `lib/tauros/revenue/invoice_revision.ex` (no update action; writes only
through `accessing_from(Invoice, :revisions)`) and
`lib/tauros/revenue/financial_payload.ex` (what is hashed, and why).

*Proof:* `test/tauros/revenue/financial_payload_test.exs`.

## 7. Deterministic state machines

Read [concepts/financial-state-machines.md](concepts/financial-state-machines.md),
the `state_machine` block in `invoice.ex`, and
`lib/tauros/revenue/changes/transition.ex`, which locks the row and asks the
state machine about the current state rather than the caller's copy.

*Try:* [exercise 2, skip the state machine](EXERCISES.md#2-skip-the-state-machine).
*Proof:* `test/tauros/revenue/invoice_lifecycle_test.exs`.

## 8. Idempotency

Read [concepts/idempotency.md](concepts/idempotency.md) and
`lib/tauros/revenue/invoice/changes/propose_revision.ex`.

*Try:* [exercise 3, replay a request](EXERCISES.md#3-replay-a-request).

## 9. Exact-payload human approval

Read `lib/tauros/revenue/invoice/changes/decide.ex` and
`lib/tauros/revenue/approval.ex`. Then open the approval inbox
(`/approvals`, signed in as `demo@tauros.local`) and compare what you see
with the `canonical_payload` it shows.

*Try:* [exercise 4, mutate approved intent](EXERCISES.md#4-mutate-approved-intent).
*Proof:* `test/tauros/revenue/approval_test.exs`, `test/tauros_web/live/approval_live_test.exs`.

## 10. Adversarial authority tests

Read `test/tauros/adversarial_test.exs` top to bottom. Every test is an
attack, and its comment names the guard that stops it. Then read
`test/tauros_web/live/adversarial_live_test.exs`: hiding a button is not
authorization.

*Try:* [exercise 5, impersonate authority](EXERCISES.md#5-impersonate-authority),
including breaking the policy on purpose, and the bonus
[tampering exercise](EXERCISES.md#6-tamper-behind-tauross-back-bonus).

## 11. AI exposure with AshAI (Epic 4)

The domain came first; the AI surface is a thin layer on top. Read
[MCP.md](MCP.md), then follow these ideas in order:

1. **Domain rules first.** Nothing in this stop adds a business rule. Every
   tool runs an action you have already read, under the same policies.
2. **Actor identity.** `/mcp` accepts only an agent API key (the `:mcp`
   pipeline in `lib/tauros_web/router.ex`, `ApiAuth.require_agent/2`). The
   agent is the actor; a human's token is refused.
   (`test/tauros_web/mcp/authentication_test.exs`)
3. **A reviewed capability surface.** `Tauros.Authority.mcp_tools/0` names
   eight tools, narrower than everything an agent may do.
4. **Tool schemas are generated.** Read the `tools` block in
   `lib/tauros/revenue.ex`, then the schema AshAI generates from the action
   arguments (`tools/list`). Money is a decimal string, never a JSON number.
   (`test/tauros/mcp_tools_test.exs`, "schema contract")
5. **Model-visible tools are an allowlist,** and it is exact: the test compares
   Authority, the domain, the router and a live `tools/list` for equality.
6. **Ash policies remain the real authority boundary.** The MCP layer
   authenticates, selects, shapes and formats; it never decides.
7. **The AI never receives an approval tool**, and if it guessed one, the
   policy would still refuse it ("Layer 1 / Layer 2" in
   `test/tauros_web/mcp/attacks_test.exs`).
8. **Prompt injection cannot manufacture authority.** Read the test of that
   name: a fully obedient client still has no path.
9. **The same actions behave identically through REST and MCP**: idempotency,
   cross-tenant errors and the state machine are the same; only the offered
   set differs. (`test/tauros_web/mcp/tools_test.exs`)
10. **MCP actions are auditable as MCP**: `interface: :mcp` in the invoice
    history, metadata that no policy reads.

*Try:* exercises 7–11 in [EXERCISES.md](EXERCISES.md#exercises-for-ai-clients-mcp)
(discover tools, create a proposal, try to approve, replay a draft,
cross-tenant request), or run `docs/examples/mcp_walkthrough.sh`.

## Further concepts

- [Auditability](concepts/auditability.md): what the envelope records today, and what Epic 5 adds
- [Eventual consistency and reconciliation](concepts/eventual-consistency.md): Epic 6
- [Intent, authority, execution](concepts/intent-authority-execution.md): the frame for all of the above
