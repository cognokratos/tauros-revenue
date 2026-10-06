# Lesson 7 · Idempotency and retries

*Part II: Financial intent* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 8](08-exact-payload-approval.md)

## Goal

Make every financial command safe to repeat, because every caller (browsers,
HTTP clients, MCP clients, LLMs) retries.

## Concept

`create_draft` takes an idempotency key: same agent + key + payload returns
the original invoice; same key + different payload is a 409 conflict. "Same
payload" means the same financial payload hash, so an LLM that rewords its
reasoning on retry still gets a replay. Transitions are retry-safe too.
Deep dive: [concepts/idempotency.md](../concepts/idempotency.md).

## Code to inspect

- `lib/tauros/revenue/invoice/changes/propose_revision.ex`: lock the agent row, look up the key, compare hashes
- `invoices_idempotency_key_per_agent_index`: the unique index that backs it
- `Transition`'s `idempotent?: true` and `Decide`'s replay rule

## Run it

```bash
mix test test/tauros/revenue/invoice_test.exs
```

The describe block "idempotency" is this lesson.

## Break it

Lab: [Exercise 3 · Replay a request](../EXERCISES.md#3-replay-a-request), over
HTTP: the same key twice, then one changed amount.

## Why it fails

The second call finds the key, hashes the payload, and returns the original
(`meta.idempotent_replay: true`). The changed amount produces a different hash:
409 `idempotency_conflict`. Concurrent duplicates serialize on the agent row
lock; the unique index is the backstop
(`test/tauros/adversarial_test.exs`, "concurrent duplicate draft creation
produces one invoice").

## What to remember

- A unique constraint alone is not idempotency; compare the payload.
- Keys are scoped to the actor.
- Retries of transitions answer without writing (and without an audit event).

**Next:** [Lesson 8 · Exact-payload approval](08-exact-payload-approval.md)
