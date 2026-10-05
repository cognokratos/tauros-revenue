# Roadmap

Each epic delivers a working capability **and** teaches one idea of agentic
financial workflow engineering. Epics 1 and 2 are done. Their numbering, scope
and functional requirements (FR) come from the original product plan. Epics 3+
rework the original backlog around Ash, AshAI, explicit state machines and
human authority.

## Definition of done for every financial command

These criteria apply to every story that changes financial state:

1. It is an **Ash action** with a description, and every interface calls that action.
2. **Policies** state which actor kind may run it, and tests prove that the other
   kinds are refused.
3. If it changes lifecycle state, it is a **state-machine transition**. No action
   accepts `state` as input.
4. It is **idempotent** ([concept](concepts/idempotency.md)), with a test that
   repeats the call.
5. It is **audited** (once Epic 5 lands): actor, actor kind, interface, before
   and after.
6. Its exposure is **explicit**: whether it is a JSON:API route, whether it is an
   AshAI tool, and why.

---

## ✅ Epic 1: Humans, agents and ownership (FR1–FR4)

*Teaches: authorization belongs to the domain, not the screens.*

| Story | Before (Ecto contexts) | Now (Ash) | Lesson |
| --- | --- | --- | --- |
| 1.1 Admin authentication | phx.gen.auth plus a custom opaque API token and plug | AshAuthentication: password (Argon2id), magic link, bearer tokens, generated UI | Authentication is configuration, not code |
| 1.2 Register agent | admin typed a key; every request bcrypt-scanned all agents | `api_key` strategy: generated, shown once, SHA-256, rotatable, O(1) lookup | Credentials are issued, never chosen |
| 1.3 Register customer | context function checked agent ownership | `relates_to_actor_via([:agent, :user])` checked post-insert | Policies cover creates too |
| 1.4 Customer ownership | `agent_id` rejected by hand-written checks; agent screens unscoped | `update` doesn't accept `agent_id`; every read is policy-filtered | Make the wrong thing impossible to express |

## ✅ Epic 2: Wallet account onboarding (FR5–FR8)

*Teaches: an agent can propose; the domain validates; the human sees everything.*

| Story | Before | Now | Lesson |
| --- | --- | --- | --- |
| 2.1 Agent registers wallet account | `X-API-KEY` plug; unknown currencies skipped validation; no FK | `relate_actor(:agent)`; currencies grouped by rail with `where:` validations; real FK; append-only | Payment destinations are high-risk data |
| 2.2 Human views wallet accounts | join query in the context; dead PubSub subscription | generated LiveView over a policy-filtered read | Reads are authorized, not filtered by hand |

---

## Epic 3: Invoice drafts and the human approval gate (FR9–FR14)

*Teaches: [intent, authority, execution](concepts/intent-authority-execution.md);
[financial workflows are state machines](concepts/financial-state-machines.md).*

Adds AshStateMachine, and AshMoney (or Decimal) for amounts. It replaces
original stories 3.1–3.5.

- **3.1 Human authority roles.** Close open registration (invitation or first-user
  bootstrap). Add an `approver` capability on users and a `HumanActor`-plus-role
  check. *AC:* only approvers can run approval actions; registration is no longer
  open.
- **3.2 Invoice draft.** An `Invoice` with lines and Money amounts, belonging to
  an agent, a customer **of the same agent** and a wallet account **of the same
  agent** whose currency matches the invoice currency. `create_draft` takes a
  required `idempotency_key`, unique per agent. *AC:* the same key and payload
  returns the same draft; the same key with a different payload is an error;
  mismatched owner or currency is rejected.
- **3.3 Invoice lifecycle.** AshStateMachine with `draft → pending_approval →
  approved | rejected`, `pending_approval → draft` (request changes), and
  `draft/approved → cancelled`. *AC:* no action accepts `state`; illegal
  transitions fail for every actor; `possible_next_states` is exposed to the UI.
- **3.4 Approval inbox.** The "Quiet Ledger" LiveView ([UX.md](UX.md)): pending
  invoices on the left, the agent's reasoning and the destination on the right.
  Drafts can be edited, and editing a pending invoice returns it to `draft`.
  *AC:* nothing is approved without an explicit click; there is an empty state.
- **3.5 Approve or reject bound to the payload.** An `Approval` record holds the
  approver, decision, reason and the SHA-256 of the canonical invoice payload.
  *AC:* approving is idempotent; changing the invoice after approval voids the
  approval.
- **3.6 The gate holds on every interface.** Tests show that an agent can't
  approve, reject or cancel through the action, the API or (later) AI tools,
  even with a valid key. The original story 3.5 called this "enforce human
  approval gate".

## Epic 4: AI capabilities with AshAI (FR18–FR23)

*Teaches: [AI capability is not authority](AI-AUTHORITY.md). Build the domain
first, then expose a reviewed subset.*

Adds AshAI. It replaces the handwritten MCP server planned in original stories
3.1 and 6.1.

- **4.1 MCP endpoint for agents.** The AshAI MCP router at `/mcp`, authenticated
  with the agent's API key through the same AshAuthentication strategy. *AC:* an
  unauthenticated call is refused, and tools run as the agent actor.
- **4.2 Read-only tools.** `list_customers`, `list_wallet_accounts`,
  `get_invoice`, `list_invoices`. *AC:* results are the agent's own records only.
  This meets journey 3's need for agents to fetch customer and account data.
- **4.3 Proposal tools.** `create_invoice_draft` (with `idempotency_key` and
  `reasoning`), `update_draft`, `submit_for_approval`. *AC:* the agent's reasoning
  is stored and shown in the inbox; a missing-data error explains how to fix it.
- **4.4 Allowlist test.** A test enumerates the exposed tools and fails if an
  authority-bearing action (approve, reject, issue, record_payment, agent
  management) appears in the list.
- **4.5 MCP reference.** Tool documentation generated from action descriptions,
  plus examples. This was original story 7.3.

## Epic 5: Auditability and supervision (FR24–FR27, FR34–FR35)

*Teaches: [auditability](concepts/auditability.md). Every financial fact has
an author, a reason and a before/after.*

Adds AshPaperTrail. It replaces original stories 5.1–5.3 and 7.1.

- **5.1 Versioned financial resources.** Invoices, approvals and wallet accounts
  carry PaperTrail versions with the actor, actor kind, interface and action.
- **5.2 Append-only at the database.** The app's database role may only `INSERT`
  and `SELECT` on version and approval tables. *AC:* updating or deleting a
  version fails at the database.
- **5.3 Invoice history timeline.** Shows who did what and when, including the
  approved payload hash.
- **5.4 Supervision feed.** Recent agent actions across the human's agents,
  with Ash PubSub notifiers pushing live updates to LiveView.
- **5.5 Manual purge, audited.** Purging old versions is a human action whose own
  record survives the purge.

## Epic 6: Issuing, payments and reconciliation (FR15–FR17)

*Teaches: [eventual consistency](concepts/eventual-consistency.md). Issued,
initiated, observed, confirmed and reconciled are different facts.*

Adds AshOban. It replaces original Epic 4, whose "service sets status to
Paid/Overdue" model is dropped.

- **6.1 Issue approved invoices.** An AshOban trigger issues approved invoices
  (number assignment, delivery hook). *AC:* idempotent; a retried job never issues
  twice.
- **6.2 Settlement events.** `POST /api/v1/settlement-events` for settlement
  services (agent key with a `settlement` capability) stores raw events with an
  identity on `(source, external_id)`. *AC:* redelivery is a no-op.
- **6.3 Payment lifecycle.** `observed → confirmed → reconciled | unmatched | failed`.
  Confirmation thresholds are per rail.
- **6.4 Reconciliation.** A deterministic matching action allocates confirmed
  payments to invoices, which moves the invoice to `partially_paid` or `paid`.
  Unmatched payments go to the human inbox.
- **6.5 Overdue as a calculation.** `overdue?` is derived from the due date and
  the open balance. No service sets it.
- **6.6 Status visibility.** A list badge plus a transition timeline (original
  story 4.3).

## Epic 7: Data protection and compliance (FR28–FR30, FR33)

*Teaches: privacy and auditability can coexist if PII and financial facts are
modelled separately.*

Adds AshCloak. It replaces original stories 5.4–5.7.

- **7.1 Encrypt PII at rest.** Customer name and email use AshCloak, decrypted
  only for authorized reads.
- **7.2 GDPR export.** A human exports a customer with their invoices and audit
  history, as a generic action returning a document.
- **7.3 GDPR erasure by anonymization.** PII is replaced and financial facts
  are retained; the erasure is audited.
- **7.4 Compliance guidance.** A non-binding checklist and a region → controls
  → implementer-actions matrix, labelled as a blueprint and not legal advice.

## Epic 8: Semantic search and summaries (FR18–FR20)

*Teaches: retrieval is a read capability. It can inform a human; it can't
decide.*

Uses AshAI vectorization on PostgreSQL (pgvector). It replaces original Epic 6;
the Arcana/Ollama plan is dropped in favour of AshAI's integration.

- **8.1 Vectorized invoices.** Embeddings are refreshed by an AshOban job on change.
- **8.2 `search_invoices` tool.** Read-only and scoped to the agent; returns
  references, not just prose.
- **8.3 Human review of AI answers.** Stored queries and answers with their
  source references, viewable in the UI. This was original story 6.2.

## Epic 9: Optional Arktos integration

*Teaches: Tauros knows financial intent; Arktos knows cryptographic authority.*

- **9.1 Payout instruction boundary.** An approved, idempotent `PayoutInstruction`
  in Tauros; a behaviour-backed adapter submits it to Arktos. Tauros holds no keys.
- **9.2 Observe, don't assume.** The outcome of a submitted payout arrives as a
  settlement event (Epic 6). It is not treated as success at submission time.

---

## Not planned

- Holding keys, signing transactions, or custody of any kind (that is Arktos's job).
- Direct blockchain node connections in Tauros. Rails report through events.
- Jurisdiction-specific compliance logic. Tauros provides extension points and guidance.
- Fraud scoring and rate limiting inside the app (rate limiting belongs at the
  edge; see [SECURITY.md](SECURITY.md#known-gaps)).
