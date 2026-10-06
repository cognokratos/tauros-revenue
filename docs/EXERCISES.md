# Exercises: learn by failed attacks

Each exercise tries something an agent (or a careless human) should not be able
to do, shows the refusal, and asks you to find the exact declaration that
caused it. They run against the demo data from `mix setup`.

Start a console:

```bash
iex -S mix
```

and paste this once:

```elixir
alias Tauros.{Accounts, Revenue}
require Ash.Query

human = Ash.read_one!(Ash.Query.for_read(Accounts.User, :get_by_email, %{email: "demo@tauros.local"}), authorize?: false)
[agent | _] = Accounts.list_agents!(actor: human)
[customer | _] = Revenue.list_customers!(actor: agent)
[destination | _] = Revenue.list_payment_destinations!(actor: agent, query: [filter: [currency: :EUR]])

draft = fn attrs ->
  Map.merge(%{
    idempotency_key: "exercise-#{System.unique_integer([:positive])}",
    customer_id: customer.id,
    payment_destination_id: destination.id,
    currency: :EUR,
    due_date: Date.add(Date.utc_today(), 30),
    lines: [%{description: "Consulting", quantity: "2", unit_amount: "500"}],
    reasoning: "Exercise"
  }, attrs)
end
```

`human` is the demo approver, `agent` its billing agent.

## 1. Break ownership

Make a second agent with its own customer, then let the first agent bill that
customer:

```elixir
other = Accounts.create_agent!("Other agent", actor: human)
theirs = Revenue.create_customer!(%{name: "Not yours", email: "x@example.com", agent_id: other.id}, actor: human)

Revenue.create_invoice_draft(draft.(%{customer_id: theirs.id}), actor: agent)
# {:error, %Ash.Error.Invalid{… message: "is not one of this agent's customers"}}

Revenue.create_invoice_draft(draft.(%{customer_id: Ash.UUID.generate()}), actor: agent)
# the same error for an id that does not exist
```

**Find it.** `lib/tauros/revenue/invoice_revision/validations/usable_references.ex`.
Why does it load the customer with `authorize?: false` and compare `agent_id`
instead of trusting the id it was given? Why is the error for "someone else's"
and "does not exist" identical?

## 2. Skip the state machine

Approve a draft that was never submitted:

```elixir
invoice = Revenue.create_invoice_draft!(draft.(%{}), actor: agent)
revision = Ash.load!(invoice, :current_revision, actor: human).current_revision

Revenue.approve_invoice(invoice, %{revision_id: revision.id, payload_hash: revision.payload_hash}, actor: human)
# {:error, … %AshStateMachine.Errors.NoMatchingTransition{old_state: :draft, target: :approved}}
```

**Find it.** The `state_machine` block in `lib/tauros/revenue/invoice.ex`:
which line lists the states `:approve` may leave from? Now try
`Ash.Changeset.for_update(invoice, :submit_for_approval, %{state: :approved}, actor: agent)`.
Why is that refused before the state machine is even asked?

## 3. Replay a request

Over HTTP, as an agent would. The seed output printed the agent's API key; if
you lost it, rotate it on the agent's page in the UI.

```bash
KEY=tauros_…   # the agent key
CUSTOMER=…     # GET /api/v1/customers with the key
DESTINATION=…  # GET /api/v1/payment-destinations with the key (pick the EUR one)

BODY='{"data":{"type":"invoice","attributes":{
  "idempotency_key":"replay-1","customer_id":"'$CUSTOMER'",
  "payment_destination_id":"'$DESTINATION'","currency":"EUR","due_date":"2099-01-31",
  "lines":[{"description":"Consulting","quantity":"2","unit_amount":"500"}],
  "reasoning":"First try"}}}'

for i in 1 2; do
  curl -s -X POST localhost:4000/api/v1/invoices \
    -H "authorization: Bearer $KEY" -H 'content-type: application/vnd.api+json' \
    -d "$BODY" | jq '{id: .data.id, replay: .meta.idempotent_replay}'
done
# the same id twice; replay is false, then true

curl -s -X POST localhost:4000/api/v1/invoices \
  -H "authorization: Bearer $KEY" -H 'content-type: application/vnd.api+json' \
  -d "$(echo "$BODY" | sed 's/"500"/"501"/')" | jq '.errors[0] | {status, code}'
# {"status": "409", "code": "idempotency_conflict"}
```

**Find it.** `lib/tauros/revenue/invoice/changes/propose_revision.ex`. What
is locked before the key is looked up, and why? What exactly is compared? Try
the replay again with a different `reasoning`: is it a conflict?

## 4. Mutate approved intent

Submit, approve, then try to change the amount:

```elixir
invoice = Revenue.create_invoice_draft!(draft.(%{}), actor: agent) |> Revenue.submit_invoice!(actor: agent)
r1 = Ash.load!(invoice, :current_revision, actor: human).current_revision
{:ok, approved} = Revenue.approve_invoice(invoice, %{revision_id: r1.id, payload_hash: r1.payload_hash}, actor: human)

Revenue.revise_invoice(approved, %{lines: [%{description: "Consulting", quantity: "3", unit_amount: "500"}], reasoning: "More"}, actor: agent)
# {:error, … NoMatchingTransition{old_state: :approved, target: :draft}}
```

Now do it *before* approval, and approve the revision you saw first:

```elixir
invoice = Revenue.create_invoice_draft!(draft.(%{}), actor: agent) |> Revenue.submit_invoice!(actor: agent)
seen = Ash.load!(invoice, :current_revision, actor: human).current_revision

Revenue.revise_invoice!(invoice, %{lines: [%{description: "Consulting", quantity: "3", unit_amount: "500"}], reasoning: "More"}, actor: agent)
|> Revenue.submit_invoice!(actor: agent)

current = Ash.load!(invoice, :current_revision, actor: human).current_revision
{seen.payload_hash, current.payload_hash}   # two different hashes

Revenue.approve_invoice(invoice, %{revision_id: seen.id, payload_hash: seen.payload_hash}, actor: human)
# {:error, … %Tauros.Revenue.Errors.Conflict{code: :stale_revision}}
```

**Find it.** Which fields of `seen` and `current` differ? Read
`Tauros.Revenue.FinancialPayload`: which of them are part of the hash? Then
read the checks in `lib/tauros/revenue/invoice/changes/decide.ex`.

## 5. Impersonate authority

Call the approval action as the agent:

```elixir
invoice = Revenue.create_invoice_draft!(draft.(%{}), actor: agent) |> Revenue.submit_invoice!(actor: agent)
r = Ash.load!(invoice, :current_revision, actor: agent).current_revision

Revenue.approve_invoice(invoice, %{revision_id: r.id, payload_hash: r.payload_hash}, actor: agent)
# {:error, %Ash.Error.Forbidden{}}
```

**Find it.** The last policy in `lib/tauros/revenue/invoice.ex` and
`lib/tauros/accounts/checks/human_approver.ex`. Which line fails for an agent?

**Then break it on purpose.** In that policy, replace `forbid_unless
HumanApprover` with `authorize_if relates_to_actor_via(:agent)` and run:

```bash
mix test test/tauros/authority_test.exs test/tauros/adversarial_test.exs
```

`AuthorityTest` fails ("agent was allowed Tauros.Revenue.Invoice.approve"),
but the agent *still* cannot approve. Why? (Read the `policies` block of
`lib/tauros/revenue/approval.ex`.) Restore the line afterwards.

## 6. Tamper behind Tauros's back (bonus)

```elixir
invoice = Revenue.create_invoice_draft!(draft.(%{}), actor: agent) |> Revenue.submit_invoice!(actor: agent)
r = Ash.load!(invoice, :current_revision, actor: human).current_revision

Tauros.Repo.query!("UPDATE invoice_revisions SET due_date = due_date + 1 WHERE id = $1", [Ecto.UUID.dump!(r.id)])

Revenue.approve_invoice(invoice, %{revision_id: r.id, payload_hash: r.payload_hash}, actor: human)
# {:error, … Conflict{code: :payload_integrity}}
```

**Find it.** `sealed?/2` in `decide.ex`. What would stop this attack at the
database level instead? (See Epic 5 in [ROADMAP.md](ROADMAP.md).)

---

# Exercises for AI clients (MCP)

These use the MCP endpoint as an AI client would. Start the app
(`mix phx.server`) and, in another shell:

```bash
source docs/examples/mcp_env.sh
```

That gives you a fresh agent key in `$KEY`, the demo approver's token in
`$TOKEN`, and the helpers `mcp`, `call` and `out` (see [MCP.md](MCP.md)).

## 7. Discover tools

```bash
mcp "$KEY" tools/list '{}' | jq '[.result.tools[] | {name, description: (.description | split("\n")[0])}]'
```

Eight tools. **Find what is missing.** Which invoice actions exist in
`lib/tauros/revenue/invoice.ex` but have no tool? Which agent-safe action in
`lib/tauros/authority.ex` is deliberately not a tool, and why
([MCP.md](MCP.md#deliberately-absent))? Then try the same request with
`$TOKEN` instead of `$KEY`: why is a human refused here but not on REST?

## 8. Create a proposal

```bash
CUSTOMER=$(call list_customers '{}' | jq -r '.result.structuredContent.results[0].id')
DEST=$(call list_payment_destinations '{}' | jq -r '.result.content[0].text | fromjson | .[0].id')

INPUT=$(jq -n --arg c "$CUSTOMER" --arg d "$DEST" '{input:{idempotency_key:"ex-8",
  customer_id:$c, payment_destination_id:$d, currency:"USDC", due_date:"2099-01-31",
  lines:[{description:"Retainer",quantity:"1",unit_amount:"1200.00"}],
  reasoning:"Retainer per the agreement."}}')

INVOICE=$(call create_invoice_draft "$INPUT" | jq -r .result.structuredContent.id)
call submit_invoice "{\"id\":\"$INVOICE\"}" | out
# {"id":"…","state":"pending_approval"}
```

Now sign in at <http://localhost:4000/approvals> as `demo@tauros.local`. The
proposal is waiting, with the agent's reasoning and the exact payload hash.
**Explain** what the agent can no longer do to this proposal, and what it still
can (`revise_invoice`): what happens to a human looking at the old revision?

## 9. Try to approve

```bash
call approve_invoice "{\"id\":\"$INVOICE\"}" | out
# {"code":-32602,"message":"Tool not found: approve_invoice"}
```

That is layer 1: the capability is not offered. Now go around MCP with the
same key:

```bash
curl -s -X PATCH localhost:4000/api/v1/invoices/$INVOICE/approve -H "authorization: Bearer $KEY" \
  -H 'content-type: application/vnd.api+json' \
  -d '{"data":{"type":"invoice","id":"'$INVOICE'","attributes":{"revision_id":"'$INVOICE'","payload_hash":"'$(printf '0%.0s' {1..64})'"}}}' \
  | jq '.errors[0].status'
# "403"
```

That is layer 2. **Find the line** that refuses the agent (the last policy in
`lib/tauros/revenue/invoice.ex`), then read "prompt injection cannot
manufacture authority" in `test/tauros_web/mcp/attacks_test.exs`.

## 10. Replay a draft

```bash
call create_invoice_draft "$INPUT" | out    # the same id as in exercise 8
call create_invoice_draft "$(echo "$INPUT" | jq '.input.lines[0].unit_amount="1300.00"')" | out
# "idempotency_key: was already used by this agent for a different financial payload (idempotency_conflict)"
call create_invoice_draft "$(echo "$INPUT" | jq '.input.idempotency_key="ex-10" | .input.lines[0].unit_amount=1200.5')" | out
# "input.lines.0.unit_amount: send amounts as decimal strings …"
```

**Explain** each answer. Which one would silently lose precision if Tauros
accepted it, and where is it refused (`lib/tauros_web/mcp/strict_arguments.ex`)?

## 11. Cross-tenant request

Use the demo seeds' customer, which belongs to *another* agent ("Billing
agent"):

```bash
THEIRS=$(curl -s localhost:4000/api/v1/customers -H "authorization: Bearer $TOKEN" \
  | jq -r '.data[] | select(.attributes.name=="Acme Inc") | .id')

call create_invoice_draft "$(echo "$INPUT" | jq --arg c "$THEIRS" '.input.idempotency_key="ex-11" | .input.customer_id=$c')" | out
call create_invoice_draft "$(echo "$INPUT" | jq '.input.idempotency_key="ex-11b" | .input.customer_id="00000000-0000-4000-8000-000000000000"')" | out
# both: "revisions.0.customer_id: is not one of this agent's customers"
```

The agent's owner can see that customer; the agent cannot use it. **Find
where it fails**
(`lib/tauros/revenue/invoice_revision/validations/usable_references.ex`), and
explain why the two answers must be identical.
