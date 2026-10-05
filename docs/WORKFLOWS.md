# Workflows

What each actor can do today, step by step, and the planned flows these steps
lead into. Every step names the Ash action that implements it.

## Today

### 1. A human onboards an agent

| Step | Interface | Action |
| --- | --- | --- |
| Register and sign in | `/register`, `/sign-in` (generated) or `POST /api/v1/users/sign-in` | `User.register_with_password`, `sign_in_with_password`, magic link |
| Create an agent | `/agents/new` or `POST /api/v1/agents` | `Agent.create` issues the API key and returns it once |
| Hand the key to the agent runtime | out of band | — |
| Rotate it if leaked | agent page **Rotate API key**, or `PATCH /api/v1/agents/:id/rotate-api-key` | `Agent.rotate_api_key` revokes old keys |

### 2. A human registers customers for an agent

| Step | Interface | Action |
| --- | --- | --- |
| Create a customer and pick one of *their* agents | `/customers/new` or `POST /api/v1/customers` | `Customer.create` (policy checks the agent's owner) |
| Correct name or email | `/customers/:id/edit` or `PATCH` | `Customer.update` (ownership not editable) |
| Remove | list **Delete** or `DELETE` | `Customer.destroy` |

### 3. An agent registers where it gets paid

| Step | Interface | Action |
| --- | --- | --- |
| Register a destination | `POST /api/v1/wallet-accounts` with the agent key | `WalletAccount.create` (owner = the agent; address validated by rail) |
| Read its destinations | `GET /api/v1/wallet-accounts` | `WalletAccount.read` (only its own) |
| The human reviews all destinations | `/wallet-accounts` | `WalletAccount.read` (all of the human's agents) |

### 4. Supervision

The dashboard (`/`) counts the human's agents, customers and wallet accounts
with policy-filtered `Ash.count!`. Each list links to its detail view.

## Planned

```text
agent  ──create_invoice_draft──▶ draft ──submit_for_approval──▶ pending_approval
                                                                     │
human (approval inbox) ◀─────────────────────────────────────────────┘
   ├─ approve(payload_hash) ──▶ approved ──(AshOban) issue──▶ issued
   ├─ reject(reason)        ──▶ rejected
   └─ request_changes       ──▶ draft

settlement service ──settlement_event──▶ payment observed ──▶ confirmed
                                          └──(reconcile)──▶ invoice partially_paid / paid
```

- **Day-to-day use** (the "5-minute check-in" from the product brief). Agents
  prepare drafts all day. The human opens the approval inbox, reads each agent's
  reasoning and the destination, and approves, rejects or sends back. Nothing
  leaves Tauros until a human approves.
- **Correction.** Editing a pending invoice returns it to `draft` and voids any
  approval, because approvals are bound to the payload hash. The version history
  keeps both versions.
- **Payment.** The settlement side never says "paid". It reports observations,
  and reconciliation decides.

The details live in [concepts/financial-state-machines.md](concepts/financial-state-machines.md)
and [ROADMAP.md](ROADMAP.md).
