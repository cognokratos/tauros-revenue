# Workflows

What each actor can do, step by step. Every step names the Ash action that
implements it; the UI, the REST API and the MCP tools all call that action.

## 1. A first approver sets up Tauros

| Step | Interface | Action |
| --- | --- | --- |
| Designate the first approver (once) | console: `Tauros.Accounts.bootstrap_approver("you@example.com")`, or the seeds | `User.bootstrap_approver` (only while no approver exists; never an agent) |
| Sign in | `/sign-in` (magic link, or password after "Forgot your password?"), or `POST /api/v1/users/sign-in` | AshAuthentication strategies (no registration) |
| Invite other humans | `/invite` | `User.invite` (approvers only) with role operator or approver |

## 2. A human onboards an agent

| Step | Interface | Action |
| --- | --- | --- |
| Create an agent | `/agents/new` or `POST /api/v1/agents` | `Agent.create` issues the API key and returns it once |
| Hand the key to the agent runtime | out of band | — |
| Register customers for it | `/customers/new` or `POST /api/v1/customers` | `Customer.create` (policy checks the agent's owner) |
| Rotate the key if leaked | agent page, or `PATCH /api/v1/agents/:id/rotate-api-key` | `Agent.rotate_api_key` |

## 3. An agent registers where it gets paid

| Step | Interface | Action |
| --- | --- | --- |
| Register a destination (currency, network, address) | `POST /api/v1/payment-destinations` | `PaymentDestination.create` (owner = the agent; network must carry the currency; address checked for the rail) |
| Correct a typo | `POST` again with `supersedes_id` | the old destination becomes `superseded` in the same transaction |
| Retire one | `PATCH /api/v1/payment-destinations/:id/deactivate`, or the destination page in the UI | `PaymentDestination.deactivate` (agent or owning human) |
| The human reviews all destinations | `/destinations` | `PaymentDestination.read` |

## 4. An agent proposes an invoice; a human decides

```text
agent ──create_draft(key, customer, destination, lines, reasoning)──▶ draft (revision 1, sealed)
agent ──revise(...)──────────────────────────────────────────────────▶ draft (revision 2, sealed)
agent ──submit_for_approval──────────────────────────────────────────▶ pending_approval
                                                                          │
human approver, in Needs review (/invoices/review), sees the exact payload of the current revision
   ├─ approve(revision_id, payload_hash)        ──▶ approved
   ├─ reject(revision_id, payload_hash, reason) ──▶ rejected (terminal)
   └─ request_changes(… , reason)               ──▶ draft: the agent must revise before resubmitting
approved ──cancel(reason) (human approver)       ──▶ cancelled
draft | pending ──withdraw (agent or owner)      ──▶ cancelled
```

| Step | AI agent (MCP tool) | Agent (REST) | Human (UI) | Action |
| --- | --- | --- | --- | --- |
| Find its customers and destinations | `list_customers`, `list_payment_destinations` | `GET /customers`, `GET /payment-destinations` | — | `Customer.read`, `PaymentDestination.active` / `read` |
| Propose (retry-safe) | `create_invoice_draft` | `POST /invoices` | — | `Invoice.create_draft` |
| Check it | `get_invoice` | `GET /invoices/:id?include=current_revision` | — | `Invoice.read` |
| Change the proposal | `revise_invoice` | `PATCH /invoices/:id/revise` | — | `Invoice.revise` |
| Ask for a decision | `submit_invoice` | `PATCH /invoices/:id/submit` | — | `Invoice.submit_for_approval` |
| Review | — | — | **Needs review** → `/invoices/:id/review` | `Invoice.read` |
| **Decide** | **no such tool** | **refused (403)** | Approve / Request changes / Reject | `approve`, `request_changes`, `reject` |
| Learn why it was sent back | `get_invoice` (the decision on the current revision) | `GET /invoices/:id?include=approvals` | — | `Approval.read` |
| Withdraw | `withdraw_invoice` | `PATCH /invoices/:id/withdraw` | — | `Invoice.withdraw` |

The MCP walkthrough (`docs/examples/mcp_walkthrough.sh`, explained in
[MCP.md](MCP.md)) performs the agent's side of this table and stops at the
human boundary.

**Day-to-day use** (the "five-minute check-in" from the product brief). Agents
prepare proposals all day. The human opens **Overview**, which leads with "Needs your attention" (the nav badge shows
how many are waiting), reads each agent's reasoning and the exact payment, and
decides one proposal at a time. Nothing approves automatically, and approving
issues nothing yet.

**Correction.** Revising a pending invoice returns it to draft with a new
revision. A human who was looking at the old revision is told it changed; their
approval would not apply to it.

**Destination retired mid-review.** Approval is refused; the human requests
changes and the agent proposes a revision with an active destination.

## 5. Supervision

**Overview** (`/`) shows what needs attention, invoices by state (each opening
the filtered list) and recent activity with named actors. **Invoices** lists
every invoice, filterable by state, with what happens next; each invoice page
shows its lifecycle, whose move it is, its decisions and its history (the
audit envelope).

## Planned

```text
approved ──(AshOban) issue──▶ issued          (Epic 6)
settlement service ──settlement_event──▶ payment observed ──▶ confirmed
                                          └──(reconcile)──▶ invoice partially_paid / paid
```

The settlement side never says "paid". It reports observations, and
reconciliation decides. See [concepts/eventual-consistency.md](concepts/eventual-consistency.md)
and [ROADMAP.md](ROADMAP.md).
