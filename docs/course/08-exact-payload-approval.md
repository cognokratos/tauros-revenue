# Lesson 8 · Exact-payload approval

*Part III: Human authority* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 9](09-concurrency.md)

**Before this lesson:** Lessons 5 (revisions) and 6 (state machines), and the
demo data (`mix setup`).

## Goal

See how a human authorizes one exact, immutable payload, never "whatever the
invoice currently contains", and what the UI shows them while they do it.

## Concept

`approve` requires the `revision_id` and `payload_hash` the human saw. Inside
one transaction, with the invoice locked, Tauros checks the state, that the
revision is current, that the hash is that revision's, that the stored payload
still reproduces its hash, and that the destination is still active. Only then
is an `Approval` written, naming that revision and hash.

## Code to inspect

- `lib/tauros/revenue/invoice/changes/decide.ex`: the checks, in order
- `lib/tauros/revenue/approval.ex`: append-only; one decision per revision; writable only through an Invoice decision by a human approver
- `lib/tauros_web/live/invoice_live/review.ex`: the decision form carries the hash that was on screen

## Run it

1. `mix phx.server`, sign in as `demo@tauros.local`.
2. **Overview** shows what needs your attention; open **Needs review**.
3. Pick a proposal. Read the authority bar (*proposed by an agent, decided by you*).
4. Compare "What approving authorizes" with the agent's reasoning.
5. Approve it. You land on the invoice: state **Approved**, lifecycle complete,
   "Approved by you · revision 1 · fingerprint …" under Human decisions.
6. Open another one and **Request changes** with a reason; see how the invoice
   now says whose move it is.

```bash
mix test test/tauros/revenue/approval_test.exs test/tauros_web/live/invoice_review_live_test.exs
```

## Break it

Approve with a hash that is not the revision's, or a revision that is no
longer current:

```bash
mix test test/tauros/revenue/approval_test.exs   # "a hash that is not the revision's is refused"
```

and [Exercise 4](../EXERCISES.md#4-mutate-approved-intent) (stale revision).

## Why it fails

`Decide` compares: 409 `payload_mismatch` for the wrong hash, 409
`stale_revision` for an old revision. The UI turns that into "This proposal
changed while you were reviewing it. Nothing was decided."

## What to remember

- The approver states what they approve: revision and hash.
- An approval is a record, bound to one payload, written once.
- The UI makes the authority boundary visible: who proposed, who decides.

**Next:** [Lesson 9 · Concurrency and stale decisions](09-concurrency.md)
