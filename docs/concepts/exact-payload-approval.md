# Exact-payload approval: financial intent as immutable revisions

> A human approval authorizes one exact, immutable financial payload, never
> "whatever the invoice currently contains".

## The failure this prevents

The naive design stores an invoice as one mutable row with an `approved`
flag:

```text
agent creates invoice (1,200 USDC to 0xAAA…)
human approves                       ← approved = true
agent edits destination to 0xBBB…    ← still approved = true
system pays 0xBBB…
```

Patches such as "clear the flag on every edit" depend on every code path
remembering to clear it, including future ones and ones written by someone
else. The flaw is that **the thing approved and the thing executed are not
the same object**.

## The model

Tauros never edits financial content in place:

```text
Invoice  (identity, owner, lifecycle)
  ├── Revision 1   payload ─sha256→ e6c1…   decision: changes_requested
  ├── Revision 2   payload ─sha256→ b0ed…   decision: approved   ← what is authorized
  └── (a Revision 3 would need its own decision)
```

- **`InvoiceRevision`** is append-only. No update or destroy action exists,
  and only an Invoice action can create one.
- Each revision is **sealed** when created: its financial payload is written
  in a canonical form, stored (`canonical_payload`), and hashed
  (`payload_hash`).
- **`Approval`** names a revision and its hash. A revision gets at most one
  decision (a unique index on `revision_id`).
- Changing anything (an amount, the destination, the due date) means a new
  revision with a new hash, which is undecided.

## What is in the payload

Everything that decides who pays what, where and when; nothing that is only
presentation or record metadata. The full table, with reasons, is in
[DOMAIN_MODEL.md](../DOMAIN_MODEL.md#the-financial-payload) and in
`Tauros.Revenue.FinancialPayload`.

Two design choices are worth arguing about:

- **The reasoning is excluded.** It explains the intent but is not the intent.
  A retry that words its explanation differently is still the same proposal
  (see [idempotency](idempotency.md)).
- **The destination's address is included even though destinations are
  immutable.** The payload should describe the payment on its own, without
  trusting that another table never changes.

## Canonicalization

Two payloads that mean the same must produce the same bytes:

| Pitfall | Canonical rule |
| --- | --- |
| map key order | keys sorted at every level |
| `"1.50"` vs `"1.5"` vs `"15E-1"` | decimals normalized |
| `é` composed vs decomposed | text in Unicode NFC |
| whitespace | none |
| a future layout | a `schema` version tag inside the payload |

Line order is **kept**: an invoice is an ordered document, and reordering it is
a different document.

`test/tauros/revenue/financial_payload_test.exs` proves both halves: the same
intent always hashes the same, and every material change hashes differently.

## Approving

`Invoice.approve` requires `revision_id` and `payload_hash`: the approver
states what they saw. Inside one transaction, with the invoice row locked,
`Invoice.Changes.Decide` checks:

| Check | Failure |
| --- | --- |
| this exact decision was already made by this approver | success, nothing written (a retry) |
| any other decision exists for the revision | 409 `already_decided` |
| the state machine allows the move from the *current* state | 409 `invalid_transition` |
| the revision is the invoice's current one | 409 `stale_revision` |
| the hash is that revision's hash | 409 `payload_mismatch` |
| re-sealing the stored fields reproduces the stored hash | 409 `payload_integrity` |
| to approve: the destination (locked) is still active | 409 `destination_inactive` |

The `payload_integrity` check means a revision altered directly in the database
is never approved: its hash no longer matches its contents. (Making the tables
append-only at the database level is Epic 5.)

## Concurrency

| Situation | Outcome |
| --- | --- |
| the approver double-clicks, or retries after a timeout | one approval; both calls succeed |
| two tabs: one approves, the other rejects | the first to lock the invoice wins; the other gets `already_decided` |
| the agent revises while the human is reviewing | the human's approval names the old revision: `stale_revision`; they review the new one |
| the destination is deactivated while approval is pending | approval fails (`destination_inactive`); the human requests changes |
| the destination is deactivated *after* approval | the approval stands (history is not rewritten); issuing (Epic 6) must re-check |

Row locks serialize commands on one invoice; the unique index on approvals is
the backstop if anything ever bypassed them.

## In the UI

The approval inbox shows the payload in plain language ("Acme Inc owes 1200.00
USDC, payable on Arbitrum One to 0x…, due 2026-11-04"), the lines, the
destination's state, the revision number, the hash and the canonical bytes.
The decision form carries the `revision_id` and `payload_hash` that were on
screen. If anything changed, the human is told and shown the new revision.
