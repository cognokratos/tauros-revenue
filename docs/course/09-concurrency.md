# Lesson 9 · Concurrency and stale decisions

*Part III: Human authority* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 10](10-auditability.md)

## Goal

Know what happens when two decisions, or a decision and a change, race, and
why the outcome is always one consistent answer.

## Concept

Every invoice command locks the invoice row first, so commands on one invoice
run one after another. Approval also locks the destination row, so a
deactivation cannot slip in halfway. A unique index allows one decision per
revision, whatever the application does.

| Race | Outcome |
| --- | --- |
| double click / retry after timeout | one approval; both calls succeed |
| approve vs reject from two tabs | first wins; the other gets `already_decided` |
| agent revises while the human reads | the human's approval is `stale_revision` |
| destination retired while pending | approval is `destination_inactive` |

## Code to inspect

- `lib/tauros/revenue/invoice/changes/decide.ex`: `lock/2`, the replay rule
- `approvals_one_decision_per_revision_index` in the approvals migration

## Run it

```bash
mix test test/tauros/adversarial_test.exs   # describe "concurrency", "revision safety"
mix test test/tauros/adversarial_test.exs --repeat-until-failure 20
```

## Break it

```bash
mix test test/tauros/revenue/approval_test.exs   # "the database allows one decision per revision, whatever the code does"
```

That test inserts a second approval with raw SQL, bypassing Tauros entirely.

## Why it fails

Postgres refuses it: the unique index on `approvals.revision_id`. Locks keep
the application consistent; the index keeps the database consistent even if
the application were wrong.

## What to remember

- Lock, then check: decide against the current row.
- Retries are answered, not repeated.
- Put the last line of defence in the database.

**Next:** [Lesson 10 · Auditability](10-auditability.md)
