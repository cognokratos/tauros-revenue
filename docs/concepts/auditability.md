# Auditability

An audit trail is useful only if it can answer, for any financial record and
long after the fact:

| Question | Recorded as | Today |
| --- | --- | --- |
| What happened? | the action name (`approve`, `revise`) and resource | ✅ `InvoiceEvent.action` |
| Who initiated it? | actor id | ✅ `InvoiceEvent.actor_id` |
| Human or agent? | actor kind | ✅ `InvoiceEvent.actor_kind` |
| Through which interface? | `ui`, `api`, `mcp`, `console` (later `job`) | ✅ `InvoiceEvent.interface` |
| Why? | the agent's reasoning, the human's reason | ✅ `InvoiceRevision.reasoning`, `Approval.reason`, `InvoiceEvent.note` |
| What exact payload was reviewed and authorized? | revision, canonical payload and its hash | ✅ `InvoiceRevision`, `Approval.payload_hash` |
| Which retry produced it? | idempotency key | ✅ `Invoice.idempotency_key`, `InvoiceEvent.idempotency_key` |
| What existed before, and after? | a version snapshot of every record | Epic 5 (AshPaperTrail) |
| Which policy and rules applied? | application version (git SHA) | Epic 5 |
| What external event caused it? | the stored inbound event | Epic 6 |

## What exists now: a lightweight envelope

This learning phase adds just enough to explain every authority-bearing
command, without pulling the audit epic forward:

- **`InvoiceRevision`** keeps every version of an invoice's financial content,
  immutably, with the agent's reasoning and the payload hash.
- **`Approval`** is a first-class record, not a column on the invoice: who
  decided, what (decision and reason), on which revision and hash, when.
- **`InvoiceEvent`** is one row per invoice command that changed something,
  written in the same transaction by `Invoice.Changes.RecordEvent`. Replays and
  failed commands write nothing.
- The **interface** travels as Ash context: the JSON:API pipeline sets
  `interface: :api` (`TaurosWeb.ApiAuth.put_interface/2`), the MCP pipeline sets
  `interface: :mcp`, the LiveViews pass `interface: :ui`, and direct calls are
  `:console`. The same agent has the same permissions through REST, MCP or a
  direct call; MCP only offers fewer actions. It is recorded for audit
  and **never** read by authorization.

None of these resources has an update or destroy action, and no actor may
create an event or a revision directly.

`test/tauros/revenue/invoice_event_test.exs` walks a full journey (propose,
send back, revise, resubmit, approve) and answers each question above from the
recorded data.

## What remains for Epic 5

- **AshPaperTrail versions** for invoices, destinations and approvals: the
  full before and after of every change, not only the event envelope.
- **Append-only at the database.** Today immutability is enforced by the
  application (no actions, and a payload seal that detects tampering). Epic 5
  restricts the app's database role to `INSERT` and `SELECT` on revision,
  approval, event and version tables.
- **Destination lifecycle events** and agent and key management events.
- **Application version** on every record.
- **A supervision feed** with live updates.

## Retention and erasure

Financial facts (amounts, dates, states, who approved) are retained. Personal
data (customer names and emails) will be encrypted at rest (AshCloak, Epic 7)
and erased by anonymization, so the audit trail keeps referring to an
anonymized customer id. This is one reason customer contact details are
**not** part of the hashed payload: erasing them must not invalidate an
approval.
