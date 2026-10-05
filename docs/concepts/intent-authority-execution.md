# Intent, authority, execution

Most failures of "agentic" financial systems come from collapsing three
different questions into one function call:

| | Question | Who answers | In Tauros |
| --- | --- | --- | --- |
| **Intent** | *What should happen?* | an agent (or a human) proposes | an invoice revision: "Acme owes 1,200 USDC on Arbitrum to 0x…, because…" |
| **Authority** | *May it happen?* | the application, deterministically, and for some transitions a recorded human decision | Ash policies, validations, the state machine, and an `Approval` bound to one payload hash |
| **Execution** | *Make it happen.* | jobs and external systems | issuing and settlement (Epic 6); signing stays with a custody system such as Arktos |

## Why keep them apart

**Intent is cheap and untrusted.** An LLM can produce a thousand plausible
intents a minute, and so can a buggy integration or a replayed HTTP request.
Expressing intent must therefore be harmless: it creates a *proposal* (a draft,
a pending invoice), never a fact.

**Authority must not depend on who phrased the intent well.** If the model can
talk its way past a check, the check is part of the prompt and not part of the
system. In Tauros a policy reads the actor and the record, and the state
machine reads the current state. Neither ever reads the conversation.

**Execution must be repeatable and observable.** It talks to the outside world,
which fails, times out and retries. It belongs in idempotent actions and
durable jobs, so that "approved" never silently becomes "half sent".

## The invoice flow (implemented up to approval)

```text
INTENT      agent  create_draft(customer, destination, lines, reasoning, key)  → draft, revision 1 sealed
            agent  revise(...)                                                 → revision 2 sealed
            agent  submit_for_approval                                          → pending_approval
AUTHORITY   human  approve(revision_id, payload_hash)                           → approved
                   policy: HumanApprover · state machine: from pending_approval
                   Decide: current revision, exact hash, intact seal, active destination
EXECUTION   job    issue (Epic 6, idempotent)                                   → issued
            rail   payment observed → confirmed → reconciled                    → paid
```

The approval is bound to the **exact payload** that was reviewed. If the
proposal changes, it is a new revision with a new hash, and the old approval
cannot apply to it. This closes the "approve one thing, execute another" gap.
See [exact-payload approval](exact-payload-approval.md).

## Where each part lives in the code

| Part | Code |
| --- | --- |
| intent | `Invoice.create_draft`, `revise`, `submit_for_approval`; `InvoiceRevision` (immutable); `PaymentDestination.create` |
| authority | the `policies` blocks; `Tauros.Accounts.Checks.HumanApprover`; the `state_machine` blocks; `Invoice.Changes.Decide`; `Approval` |
| execution | not yet in Tauros: Epic 6 (AshOban issuing, settlement events), Epic 9 (Arktos adapter) |
