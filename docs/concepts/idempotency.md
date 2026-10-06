# Idempotency

Everything that calls Tauros retries: browsers double-submit, HTTP clients retry
on timeouts, MCP clients retry tool calls, Oban retries jobs, and payment
providers redeliver webhooks. An LLM agent may also decide, on reflection, to
"try again". Every financial command must therefore be **safe to repeat**:
running it twice has the same effect as running it once.

## Three techniques, by command type

| Command | Technique | In Tauros |
| --- | --- | --- |
| Create something from an external request | **Idempotency key**, unique per actor; compare the payload on replay | `Invoice.create_draft` ✅ |
| State transition | **The goal state already holds because of this same command** → no-op success | `submit_for_approval`, `withdraw`, `cancel`, `approve`/`reject`/`request_changes` ✅ |
| Process an external event | **Natural key**, e.g. `(source, external_id)` | settlement events (Epic 6) |

## `create_draft`: the contract

```text
same agent + same key + same payload      → the original invoice  (meta.idempotent_replay = true)
same agent + same key + different payload → 409 idempotency_conflict, nothing written
different agent + same key                → independent invoices (keys are scoped to the agent)
```

How it is built (`Invoice.Changes.ProposeRevision`), inside the create
transaction:

1. **Lock the agent's row** (`SELECT … FOR UPDATE`). Concurrent creates by the
   same agent now run one after another, so "look up, then insert" cannot race.
2. **Look up** an invoice with this agent and key.
3. **Compare payloads.** "Same payload" means the same
   [financial payload hash](exact-payload-approval.md) as the invoice's first
   revision. The hash ignores formatting (`400` = `400.00`) and the agent's
   reasoning, so an LLM that rewords its explanation on retry still gets a
   replay, while any change to the money is a conflict.
4. A **unique index** on `(agent_id, idempotency_key)` is the backstop if
   anything ever bypassed steps 1–3.

A replay returns the invoice as it is *now*: if it was revised or withdrawn
since, the agent sees that. A replay also succeeds if the destination was
retired after the original call; the original succeeded, and replaying it
creates nothing.

Putting a unique constraint on a key is not enough on its own: a duplicate then
fails with a database error, the client cannot tell "you already did this"
from "something broke", and a reused key with different content is never
noticed.

## Transitions

| Command retried | Result |
| --- | --- |
| `submit_for_approval` on a pending invoice | success, nothing changes |
| `withdraw` / `cancel` on a cancelled invoice | success, nothing changes |
| `approve` (or reject / request changes) by the same approver, same revision and hash | success, still one approval |
| a different decision, or a different approver, on a decided revision | 409 `already_decided` |
| `revise` to exactly the current payload | success, no new revision |

The shared `Tauros.Revenue.Changes.Transition` implements the first two with
its `idempotent?: true` option; `Invoice.Changes.Decide` implements the
decision replay. Replays write no audit event, because nothing happened.

## Rules

- **Keys are scoped to the actor.** Agent A's `inv-42` is not agent B's `inv-42`.
- **A key replayed with a different payload is an error**, never a silent success.
- **Side effects are executed by jobs keyed by the record** (Epic 6), never
  fired inline from a request that might be retried.
- **Idempotency is tested at the action level**, then every interface inherits
  it: `test/tauros/revenue/invoice_test.exs` ("idempotency"),
  `test/tauros/adversarial_test.exs` (concurrent duplicates).

## Try it

[Exercise 3](../EXERCISES.md#3-replay-a-request) sends the same key twice over
HTTP, then changes one amount.
