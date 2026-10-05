# Idempotency

Everything that calls Tauros retries: browsers double-submit, HTTP clients retry
on timeouts, MCP clients retry tool calls, Oban retries jobs, and payment
providers redeliver webhooks. An LLM agent may also decide, on reflection, to
"try again". Every financial command must therefore be **safe to repeat**:
running it twice has the same effect as running it once.

## Three techniques, by command type

| Command | Technique | Ash mechanism |
| --- | --- | --- |
| Create something from an external request: create an invoice draft, record a payment | **Idempotency key.** The client sends a key, and the key is unique per actor. A repeat returns the original record. | `attribute :idempotency_key`, `identity [:agent_id, :idempotency_key]`, `create ... upsert? true, upsert_identity: ...` that changes nothing on conflict |
| State transition: submit, approve, issue | **Transition guard.** Approving an already approved invoice is a no-op success, never a second approval. | AshStateMachine transitions plus a `where` that returns the current record when already in the target state |
| Process an external event: settlement notice, webhook | **Natural key.** The event is stored once by `(source, external_id)`. Processing is a separate, repeatable step. | identity on the event resource; the AshOban trigger processes unprocessed events |

## Rules

- **Keys are scoped to the actor.** Agent A's `inv-42` is not agent B's `inv-42`.
- **A key replayed with a different payload is an error**, not a silent success.
  Store a hash of the original input and compare it on replay.
- **Side effects are executed by jobs keyed by the record**, never fired inline
  from a request that might be retried. AshOban schedules work from record state,
  so re-running the scheduler cannot double-issue.
- **Idempotency is tested at the action level**, for example "call
  `create_invoice_draft` twice with the same key and assert there is one row".
  Then every interface (UI, REST, MCP) inherits it.

## In the roadmap

Idempotency is an acceptance criterion of every financial command in
[ROADMAP.md](../ROADMAP.md), not a later hardening epic. The current scope has
little to make idempotent. Agent registration is human-driven, and wallet
accounts are append-only records an agent registers once. Requiring an
`idempotency_key` arrives with the first command an agent will retry
autonomously: creating invoice drafts.
