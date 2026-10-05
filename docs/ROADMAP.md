# Roadmap

Each epic delivers a working capability **and** teaches one idea of agentic
financial workflow engineering. Epics 1–4 are done. Their numbering, scope
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
5. It is **audited**: actor, actor kind, interface, revision and payload hash,
   reason (the `InvoiceEvent` envelope today; full before/after with Epic 5).
6. Its exposure is **explicit**: whether it is a JSON:API route, whether it is an
   AshAI tool, and why. It is classified in `Tauros.Authority` (agent-safe,
   human-only or internal), and `AuthorityTest` checks the policies agree.

---

## ✅ Epic 1: Humans, agents and ownership (FR1–FR4)

*Teaches: authorization belongs to the domain, not the screens.*

| Story | Before (Ecto contexts) | Now (Ash) | Lesson |
| --- | --- | --- | --- |
| 1.1 Admin authentication | phx.gen.auth plus a custom opaque API token and plug | AshAuthentication: password (Argon2id), magic link, bearer tokens, generated UI | Authentication is configuration, not code |
| 1.2 Register agent | admin typed a key; every request bcrypt-scanned all agents | `api_key` strategy: generated, shown once, SHA-256, rotatable, O(1) lookup | Credentials are issued, never chosen |
| 1.3 Register customer | context function checked agent ownership | `relates_to_actor_via([:agent, :user])` checked post-insert | Policies cover creates too |
| 1.4 Customer ownership | `agent_id` rejected by hand-written checks; agent screens unscoped | `update` doesn't accept `agent_id`; every read is policy-filtered | Make the wrong thing impossible to express |

## ✅ Epic 2: Payment destination onboarding (FR5–FR8)

*Teaches: an agent can propose; the domain validates; the human sees everything.*

| Story | Before | Now | Lesson |
| --- | --- | --- | --- |
| 2.1 Agent registers a destination (then "wallet account") | `X-API-KEY` plug; unknown currencies skipped validation; no FK | `relate_actor(:agent)`; currencies grouped by rail with `where:` validations; real FK; append-only | Payment destinations are high-risk data |
| 2.2 Human views destinations | join query in the context; dead PubSub subscription | generated LiveView over a policy-filtered read | Reads are authorized, not filtered by hand |

---

## ✅ Destination hardening (learning phase, before Epic 3)

*Teaches: [payment destinations are immutable but retirable](concepts/payment-destinations.md).*

| Change | Why |
| --- | --- |
| `WalletAccount` → `PaymentDestination`, with an explicit `network` | a currency does not imply a rail; USDC lives on several networks; an IBAN is not a wallet |
| `Network` declares which currencies it carries and which rail it is on | the address format belongs to the rail, not the currency |
| bech32m (Taproot) and IBAN mod-97 checksums; EVM labelled format-only | a regex checks shape, not typos (it had accepted an invalid test address) |
| `active → deactivated` or `superseded` lifecycle, `supersedes_id` | a destination must be able to stop being used without being deleted or edited |

## ✅ Epic 3: Invoice drafts and the human approval gate (FR9–FR14)

*Teaches: [intent, authority, execution](concepts/intent-authority-execution.md);
[financial workflows are state machines](concepts/financial-state-machines.md);
[exact-payload approval](concepts/exact-payload-approval.md);
[idempotency](concepts/idempotency.md).*

| Story | Delivered |
| --- | --- |
| 3.1 Human authority roles | registration closed; `role` operator/approver; `invite`; `bootstrap_approver`; `HumanApprover` check |
| 3.2 Invoice draft | `create_draft` with a required idempotency key; customer and destination of the same agent; destination active and receiving the invoice currency; Decimal amounts that fit the currency |
| 3.3 Invoice lifecycle | AshStateMachine; transitions checked against the locked row; no action accepts `state` |
| 3.4 Approval inbox | the Quiet Ledger at `/approvals`, plus `/invoices` |
| 3.5 Approval bound to the payload | immutable `InvoiceRevision`s with a canonical payload and SHA-256; `Approval` names one revision and hash |
| 3.6 The gate holds on every interface | `AuthorityTest`, `AdversarialTest`, API and LiveView attack tests |
| *added* | lightweight audit envelope (`InvoiceEvent`), `Tauros.Authority` classification, exercises |

**Changed from the plan, and why:**

- **Revisions instead of a mutable invoice.** The plan said "changing the
  invoice after approval voids the approval". That relies on every code path
  remembering to void it. Now financial content is never edited: a change is a
  new revision with a new hash, and an approval names one revision.
- **Decimal instead of AshMoney.** AshMoney's currency model is ISO 4217; Tauros's
  assets include tokens whose identity depends on the network, and an invoice
  has a single explicit currency. Decimal plus a `currency` field (and
  per-currency decimal places, never rounded) is simpler and exact. All
  arithmetic runs in a context that traps rounding.
- **`withdraw` and `cancel` are separate actions.** The plan had one `cancel`
  from draft or approved. Undoing an undecided proposal is capability; undoing
  an approval is authority. Separate actions keep the policy and the state
  machine from depending on each other.
- **`possible_next_states` is not exposed yet.** The inbox needs only "is it
  pending, and may this human decide?", which it asks of the domain with
  `Ash.can?`. Epic 4 did not need it either: the tool descriptions state the
  lifecycle in words, and an illegal move returns an `invalid_transition` error.
- **Organizations are out of scope.** Each human still owns their agents; an
  approver decides on their own agents' invoices. Sharing agents between
  humans (and separation of duties between people) is future work.

## ✅ Epic 4: AI capabilities with AshAI (FR18–FR23)

*Teaches: [AI capability is not authority](AI-AUTHORITY.md). Build the domain
first, then expose a reviewed subset. Reference: [MCP.md](MCP.md).*

AshAI 1.1.1, without ReqLLM. It replaces the handwritten MCP server planned in
original stories 3.1 and 6.1.

| Story | Delivered |
| --- | --- |
| 4.1 MCP endpoint for agents | `/mcp` with its own pipeline: agent API key only (human tokens refused), the agent is the actor, `interface: :mcp` in the audit envelope |
| 4.2 Read tools | `list_customers` (id, name), `list_payment_destinations` (active only, new `PaymentDestination.active` read), `list_invoices`, `get_invoice` (current revision and its decision) |
| 4.3 Proposal tools | `create_invoice_draft`, `revise_invoice`, `submit_invoice`, `withdraw_invoice`, with descriptions that say what they do *not* do |
| 4.4 Allowlist test | `Tauros.McpToolsTest`: every tool is agent-safe, and the tools are *exactly* the reviewed eight in `Tauros.Authority`, the domain, the router and a live `tools/list` |
| 4.5 MCP reference | [MCP.md](MCP.md), `docs/examples/mcp_walkthrough.sh`, exercises 7–11 |
| *added* | actionable tool errors, floats refused, schema contract test, MCP attack and prompt-injection tests |

**Changed from the plan, and why:**

- **The tool list is narrower than "agent-safe".** Deactivating a destination
  and reading the approval queue, raw revisions, approvals and events are
  allowed to an agent but not offered to a model.
- **Customer email is not shown to the model**, and customers cannot be
  filtered, so emails cannot be probed. A name is enough to choose.
- **`update_draft` is `revise_invoice`**, matching the domain action.

## Epic 5: Auditability and supervision (FR24–FR27, FR34–FR35)

*Teaches: [auditability](concepts/auditability.md). Every financial fact has
an author, a reason and a before/after.*

Adds AshPaperTrail. It replaces original stories 5.1–5.3 and 7.1.

Already in place from Epic 3: immutable revisions, approval records, and the
`InvoiceEvent` envelope (actor, kind, interface, revision, hash, reason),
shown as a timeline on each invoice. Epic 5 turns that into full history.

- **5.1 Versioned financial resources.** Invoices, approvals and payment destinations
  carry PaperTrail versions with the actor, actor kind, interface and action.
- **5.2 Append-only at the database.** The app's database role may only `INSERT`
  and `SELECT` on version, revision, approval and event tables. *AC:* updating or deleting a
  version fails at the database.
- **5.3 Full history timeline.** Extends today's event timeline with
  before/after versions, destination and agent events.
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
  twice; issuing re-checks that the approved revision's destination is still
  active (deactivation after approval does not rewrite the approval).
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
