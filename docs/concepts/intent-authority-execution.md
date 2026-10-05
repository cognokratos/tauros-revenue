# Intent, authority, execution

Most failures of "agentic" financial systems come from collapsing three
different questions into one function call:

| | Question | Who answers | In Tauros |
| --- | --- | --- | --- |
| **Intent** | *What should happen?* | a human or an agent proposes | an action input: "create an invoice for Acme, 1,200 USDC" |
| **Authority** | *May it happen?* | the application, deterministically | Ash policies, validations, the state machine and, for some transitions, a recorded human approval |
| **Execution** | *Make it happen.* | the application, a job, or an external system | the action's data-layer write; later, Oban jobs and external rails (a bank, a chain, Arktos for signing) |

## Why keep them apart

**Intent is cheap and untrusted.** An LLM can produce a thousand plausible
intents a minute, and so can a buggy integration or a replayed HTTP request.
Expressing intent must therefore be harmless: it creates a *proposal* (a draft
invoice, a pending approval), never a fact.

**Authority must not depend on who phrased the intent well.** If the model can
talk its way past a check, the check is part of the prompt and not part of the
system. In Tauros, authority is code: a policy reads the actor and the record,
and a state machine reads the current state. Neither ever reads the
conversation.

**Execution must be repeatable and observable.** It talks to the outside world,
which fails, times out and retries. It belongs in idempotent actions and durable
jobs (see [idempotency](idempotency.md) and
[eventual consistency](eventual-consistency.md)), so that "approved" never
silently becomes "half sent".

## How it already shows in the code

Even before invoices exist, the split is visible:

- An **agent** may *propose* a payment destination (`WalletAccount.create`), but
  the **domain** decides whether the address is valid for that rail, and the
  record is append-only.
- An agent cannot touch the authority layer at all: it can't create agents,
  rotate keys or create customers. `HumanActor` checks in the policies make that
  explicit.
- Issuing an API key is *execution* inside the transaction (`IssueApiKey`), and
  it runs only after authority (the agent policy) has said yes.

## The invoice flow (planned)

```text
INTENT      agent:  create_invoice_draft(customer, lines, wallet_account)   → draft
            agent:  submit_for_approval(invoice)                             → pending_approval
AUTHORITY   human:  approve(invoice, payload_hash)                           → approved
            policy: only HumanActor may approve; state machine: only from pending_approval
EXECUTION   job:    issue(invoice)  (idempotent, Oban)                       → issued
            rail:   payment observed → confirmed → reconciled                → paid
```

An approval is bound to the **exact payload** that was reviewed, by a hash of
the invoice as approved. If the draft changes, the approval no longer applies.
This closes the "approve one thing, execute another" gap.
