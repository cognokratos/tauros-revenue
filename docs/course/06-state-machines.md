# Lesson 6 · Financial state machines

*Part II: Financial intent* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 7](07-idempotency.md)

## Goal

Make the lifecycle a closed set of named moves that no actor can skip or
forge, and that holds under concurrency.

## Concept

`draft → pending_approval → approved | rejected`, `request_changes` back to
draft, `withdraw` and `cancel` to cancelled. Nobody sets `state`; changing
state *is* running a transition action. Tauros checks each transition against
the **locked current row**, not the copy the caller loaded.
Deep dive: [concepts/financial-state-machines.md](../concepts/financial-state-machines.md).

## Code to inspect

- `lib/tauros/revenue/invoice.ex`: the `state_machine` block, the only definition of the graph
- `lib/tauros/revenue/changes/transition.ex`: `SELECT … FOR UPDATE`, then ask AshStateMachine
- `withdraw` vs `cancel` in `invoice.ex`: similar moves, different authority, so different actions

## Run it

```bash
mix test test/tauros/revenue/invoice_lifecycle_test.exs
```

In the app: an invoice page shows the lifecycle strip and whose move it is.

## Break it

Lab: [Exercise 2 · Skip the state machine](../EXERCISES.md#2-skip-the-state-machine):
approve a draft, then try to pass `state: :approved` to `submit_for_approval`.

## Why it fails

`approve` is declared only from `pending_approval`: `NoMatchingTransition`. And
no action accepts `state` as input, so the second attempt is invalid before the
state machine is even asked. The test "the check uses the current row, not the
caller's stale copy" shows why the lock matters.

## What to remember

- The graph is data; transitions are named actions; `state` is never input.
- Who may run a transition is a policy, not part of the graph.
- Check transitions against the locked row, or concurrent requests both win.

**Next:** [Lesson 7 · Idempotency and retries](07-idempotency.md)
