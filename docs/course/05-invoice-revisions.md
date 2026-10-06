# Lesson 5 · Invoice revisions and the financial payload

*Part II: Financial intent* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 6](06-state-machines.md)

## Goal

Represent financial intent so that what a human approves can never differ from
what would be paid.

## Concept

An invoice holds identity and lifecycle; its money lives in **revisions** that
are never edited. Each revision is sealed when created: its financial payload
(customer, currency, lines, total, destination, due date) is written in a
canonical form and hashed with SHA-256. A change is a new revision with a new
hash. Deep dive: [concepts/exact-payload-approval.md](../concepts/exact-payload-approval.md).

## Code to inspect

- `lib/tauros/revenue/financial_payload.ex`: what is hashed, what is not, and why; exact decimal arithmetic
- `lib/tauros/revenue/invoice_revision.ex`: no update action; created only through `accessing_from(Invoice, :revisions)`
- `lib/tauros/revenue/invoice/changes/propose_revision.ex`: `create_draft` and `revise` append a revision

## Run it

```bash
mix test test/tauros/revenue/financial_payload_test.exs
```

In the app: open an invoice → **Details** → revision number, fingerprint, and
"Canonical payload (the exact bytes hashed)".

## Break it

Lab: [Exercise 4 · Mutate approved intent](../EXERCISES.md#4-mutate-approved-intent):
revise a submitted invoice and compare the two fingerprints.

## Why it fails

There is no way to change a revision: no update action exists, and writing one
directly is refused by its create policy. `revise` produces a *new* revision;
because the amount is part of the payload, the hash changes too.

## What to remember

- Approve values, not rows: seal the financial content.
- Hash only what decides who pays what, where and when; keep presentation out.
- Canonical form: sorted keys, normalized decimals, NFC text, ordered lines.

**Next:** [Lesson 6 · Financial state machines](06-state-machines.md)
