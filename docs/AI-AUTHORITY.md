# AI capability is not financial authority

Tauros exists to teach one principle:

> An AI agent may be very **capable** (it can read, search, draft, propose and
> retry), but capability never confers **authority** to approve, issue or
> otherwise finalize a financial commitment. Authority is held by humans and
> enforced by deterministic code.

This page shows how the application is built so that the principle is a
property of the system and not a line in a prompt.

## What exactly stops an agent from approving an invoice?

Five independent things, from the outermost in. Any one of them is enough.

1. **The Invoice policy** (`lib/tauros/revenue/invoice.ex`, the last policy):

   ```elixir
   policy action([:approve, :reject, :request_changes, :cancel]) do
     description "Only a human approver who owns the proposing agent decides"
     forbid_unless HumanApprover
     authorize_if relates_to_actor_via([:agent, :user])
   end
   ```

   `HumanApprover` (`lib/tauros/accounts/checks/human_approver.ex`) matches
   only `%Tauros.Accounts.User{role: :approver}`. An agent is a
   `%Tauros.Accounts.Agent{}`. The match fails, the policy forbids, and the
   action never runs. This holds for the LiveView, the JSON:API, a direct
   `Ash` call and, later, an AshAI tool, because all of them run this action.

2. **The Approval policy** (`lib/tauros/revenue/approval.ex`): an `Approval`
   can only be created through an Invoice decision (`accessing_from(Invoice,
   :approvals)`) *and* only for a `HumanApprover` who owns the agent. If the
   Invoice policy above were ever weakened by mistake, the approval record
   still could not be written. (Try it: the mutation is described in
   [EXERCISES.md](EXERCISES.md#5-impersonate-authority).)

3. **No action accepts `state`.** An agent cannot write `approved` into the
   invoice. The only way into `approved` is the `:approve` transition of the
   state machine, and that transition is guarded by 1 and 2.

4. **No agent action can express a decision.** `create_draft`, `revise`,
   `submit_for_approval` and `withdraw` accept no `state`, approval, approver
   or decision fields. Smuggling them in is rejected as invalid input.

5. **Exactness.** Even a legitimate human approval only authorizes the exact
   revision and payload hash the human named, never "whatever the invoice
   currently contains". See [exact-payload approval](concepts/exact-payload-approval.md).

`test/tauros/adversarial_test.exs` attacks each of these, and every test names
the guard that stopped it.

## Build the domain first, then expose it

```text
Human UI ──────────┐
                   │
REST API ──────────┼──→  Ash actions ──→ policies ──→ state machine ──→ database
                   │
AshAI / MCP ───────┘   (Epic 4)
```

AI tools in Tauros will be **the same Ash actions** the UI and the API call,
exposed through [AshAI](https://hexdocs.pm/ash_ai). There is no separate "AI
backend", no second copy of business logic and no handwritten MCP server.

- A policy written once holds for an LLM tool call just as it does for a REST
  request.
- A tool can never do more than the action it wraps.
- Tool descriptions come from action descriptions. The decision actions say
  `HUMAN AUTHORITY` in theirs, so a model reading the schema is told plainly.

## Exposure is an explicit allowlist

> The existence of an Ash action does not mean that action should be exposed
> through AshAI.

`Tauros.Authority` (`lib/tauros/authority.ex`) classifies every business
action:

| Class | Meaning | Examples |
| --- | --- | --- |
| `agent_safe` | capability; may become an AI tool | read customers, destinations and invoices; register or retire one's own destination; `create_draft`, `revise`, `submit_for_approval`, `withdraw` |
| `human_only` | authority; must never become an AI tool | `approve`, `reject`, `request_changes`, `cancel`; managing agents, customers and humans (`invite`, `bootstrap_approver`) |
| `internal` | no actor may call it | writing revisions, approvals and events; `supersede` |

The module enforces nothing; it is the reviewed list.
`test/tauros/authority_test.exs` makes it executable:

- every action of every business resource must be classified, so a new action
  cannot slip in unreviewed;
- an agent must be refused every `human_only` action on its own owner's
  records;
- the owning agent must be allowed every `agent_safe` action;
- no actor may call an `internal` action.

Epic 4 adds the last check: every AshAI tool must be in `agent_safe/0`. Two
layers then guard each authority action:

1. **Not exposed**: it is not in the AshAI allowlist.
2. **Not permitted**: even if it were, or the same agent called the REST route
   directly, the policy refuses it.

The allowlist limits what the model is *offered*; the policies limit what any
agent can *do*.

## The capability matrix today

| Action | Agent (API key) | Human operator | Human approver |
| --- | --- | --- | --- |
| read customers, destinations, invoices, revisions, decisions, history | ✅ its own | ✅ their agents' | ✅ their agents' |
| register, retire a payment destination | ✅ its own | retire only | retire only |
| create, revise, submit an invoice proposal | ✅ its own | ❌ | ❌ |
| withdraw an undecided proposal | ✅ its own | ✅ | ✅ |
| **approve, reject, request changes** | ❌ | ❌ | ✅ owner, exact revision |
| **cancel an approved invoice** | ❌ | ❌ | ✅ owner |
| manage agents and customers | ❌ | ✅ | ✅ |
| **invite humans** | ❌ | ❌ | ✅ |

## Who the AI acts as

An AI client authenticates as an **agent**, with that agent's API key. It acts
with that agent's permissions, never with those of the human who owns it. A
human approver's agent gains nothing from its owner's role.

## What the model may and may not do

| May (capability) | May not (authority) |
| --- | --- |
| interpret a request, read its records, summarize history | approve, reject, issue or cancel a financial commitment |
| choose one of *its own* customers and *active* destinations | use another agent's records, or a retired destination |
| prepare, revise and submit an invoice proposal with its reasoning | set or change any `state` |
| retry safely with an idempotency key | change who owns a record |
| read why a proposal was sent back, and propose a new revision | approve its own proposal, through any interface |
| | hold or use keys; sign anything |

## Why not enforce this in the prompt?

Prompts are inputs to a probabilistic component. A guardrail in a prompt is a
suggestion the model may ignore, misread or be talked out of by injected
content. Policies, state machines and allowlists are evaluated by the BEAM on
every call, whatever the conversation says. The
[`simple-agent-template`](https://github.com/cognokratos/simple-agent-template)
calls the model an *untrusted decision maker*; Tauros applies that idea to money.
