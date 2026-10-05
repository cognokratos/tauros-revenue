# Auditability

An audit trail is useful only if it can answer, for any financial record and
long after the fact:

| Question | Recorded as |
| --- | --- |
| What happened? | the action name (`approve`, `record_payment`) and resource |
| Who initiated it? | actor id |
| Human, agent or service? | actor kind (`user`, `agent`, `system`) |
| Through which interface? | `ui`, `api`, `mcp`, `job` |
| What existed before, and after? | a version snapshot or diff of the record |
| Which policy and rules applied? | the application version (git SHA) and, where relevant, a rule or policy version |
| Who approved it, and what exactly? | approval record: approver, timestamp, **hash of the approved payload** |
| What external event caused it? | reference to the stored inbound event (`source`, `external_id`) |

## How Tauros plans to record it

- **[AshPaperTrail](https://hexdocs.pm/ash_paper_trail)** on financial resources
  (invoices, payments, wallet accounts). It writes a version row per action,
  inside the same transaction, with the action name and changes. Actor
  attribution comes from the Ash actor that every interface already passes.
- **Context, not log parsing.** Interface and correlation ids travel as Ash
  context (`Ash.PlugHelpers.set_context/2` for HTTP; the MCP and job equivalents),
  so the version row records them without each LiveView or controller having to
  remember.
- **Approvals are first-class records**, not a column on the invoice. An
  approval has an approver, a decision, a reason and the payload hash.
- **Append-only by design.** Version and approval resources have no update or
  destroy actions, and the database role used by the app may only `INSERT` and
  `SELECT` on those tables.

## Retention and erasure

The original PRD required audit logs "retained until manual purge" and also GDPR
erasure. These two pull in opposite directions. The planned resolution:

- Financial facts (amounts, dates, states, who approved) are retained.
- Personal data (customer names and emails) is **encrypted at rest**
  (AshCloak) and erased by **anonymization**: the customer's PII is replaced,
  and the audit trail keeps referring to an anonymized customer id.
- A purge is itself an audited action, recorded in a table the purge does not
  touch.

## What already exists

Today, AshAuthentication's `Token` resource records sign-ins, and every row has
timestamps. Nothing else is audited yet. The current resources do already
prepare for it: every write goes through an action with an explicit actor,
there is no update or delete path for wallet accounts, and ownership fields
cannot be changed.
