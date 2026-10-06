# Lesson 10 · Auditability

*Part III: Human authority* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 11](11-breaking-the-boundary.md)

## Goal

Answer, for any invoice: who proposed it and why, what exact payload was
reviewed, who decided, and which revision and fingerprint they authorized.

## Concept

Every invoice command that changes something writes an `InvoiceEvent` in the
same transaction: action, from and to state, actor and actor kind, interface
(`ui`, `api`, `mcp`, `console`), revision and hash, and the reason. Replays and
failed commands write nothing. The interface is metadata only; no policy reads
it. Full history (AshPaperTrail) is Epic 5.
Deep dive: [concepts/auditability.md](../concepts/auditability.md).

## Code to inspect

- `lib/tauros/revenue/invoice/changes/record_event.ex`
- `lib/tauros/revenue/invoice_event.ex`: no create policy at all; no update or destroy
- `lib/tauros_web/api_auth.ex`: `put_interface/2` for `:api` and `:mcp`

## Run it

```bash
mix test test/tauros/revenue/invoice_event_test.exs
```

In the app: any invoice → **History** ("Billing agent proposed this invoice ·
via mcp", "You approved this invoice · via ui"), and **Overview** → Recent activity.

## Break it

Forge an event claiming a human approved:

```bash
mix test test/tauros/adversarial_test.exs   # "an agent forges an audit event claiming a human approved"
```

## Why it fails

`InvoiceEvent` has no create policy, so no actor is ever authorized to write
one. Only `RecordEvent`, running inside an already-authorized invoice action,
writes events.

## What to remember

- Record who, what, how, which payload and why, in the same transaction.
- Nothing is recorded for things that did not happen.
- Interface is for auditors, never for authorization.

**Next:** [Lesson 11 · Breaking the approval boundary](11-breaking-the-boundary.md)
