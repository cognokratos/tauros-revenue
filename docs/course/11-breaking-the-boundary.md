# Lesson 11 · Breaking the approval boundary

*Part III: Human authority* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 12](12-ashai-and-mcp.md)

## Goal

Attack the approval boundary every way you can think of, and be able to name,
for each attack, the line of code that stops it.

## Concept

Tauros teaches through failed attacks. `test/tauros/adversarial_test.exs`
groups them: authority escalation, state manipulation, cross-tenant access,
idempotency, revision safety, destination safety, concurrency. Every test
names its guard. `Tauros.Authority` lists every action as agent-safe,
human-only or internal, and `AuthorityTest` holds the policies to that list.

## Code to inspect

- `test/tauros/adversarial_test.exs`, read top to bottom
- `lib/tauros/authority.ex` and `test/tauros/authority_test.exs`
- The last policy in `lib/tauros/revenue/invoice.ex`, and the `policies` of `lib/tauros/revenue/approval.ex`

## Run it

```bash
mix test test/tauros/adversarial_test.exs test/tauros/authority_test.exs test/tauros_web/live/adversarial_live_test.exs
```

## Break it

Lab: [Exercise 5 · Impersonate authority](../EXERCISES.md#5-impersonate-authority),
including **weakening the approve policy on purpose** and rerunning the tests.
Then [Exercise 6](../EXERCISES.md#6-tamper-behind-tauross-back-bonus):
edit a revision in the database and try to approve it.

## Why it fails

With the Invoice policy weakened, `AuthorityTest` fails immediately, and the
agent *still* cannot approve: the `Approval` resource's own policy
(`accessing_from` and `HumanApprover`) refuses to write the record. Two
independent layers. The tampered revision fails `payload_integrity`: its
stored hash no longer matches its contents.

## What to remember

- Write attacks as tests, and name the guard in each.
- Classify every action; let a test hold the policies to the classification.
- Defence in depth: no single line should be the only thing in the way.

**Next:** Part IV. [Lesson 12 · AshAI and MCP](12-ashai-and-mcp.md)
