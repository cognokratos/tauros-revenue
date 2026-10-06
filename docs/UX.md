# UX direction

These decisions come from the original UX specification, refined by a
browser review of the running app before the PR. Setup screens are the
generated AshPhoenix LiveViews; the overview and the invoice workflow are
purpose-built.

## Information architecture

Navigation follows what a human does, not the database:

```text
Overview                      what needs attention, invoices by state, recent activity
Revenue    Needs review (n)   the proposals waiting for a human decision
           Invoices           every invoice, filterable by state
Business   Customers · Destinations
Automation Agents
Admin      Invite             (approvers only)
```

Reviewing is a step of an invoice's lifecycle, not a separate object, so it
lives under invoices: `/invoices/review` (the queue) and `/invoices/:id/review`
(one decision). An invoice page links to its review when it is pending; the
review links back to the invoice; a decision lands on the invoice with its new
state. There are no dead ends: every invoice page says what happens next, and
offers the next proposal to review.

## Terminology

| Term in the UI | Means | Domain |
| --- | --- | --- |
| **Pending approval** | the state of a submitted proposal | `state: :pending_approval` |
| **Needs review** | the human's queue of pending proposals | `Invoice.awaiting_approval` |
| **Approve** | authorize this exact revision | `Invoice.approve` |
| **Request changes** | send it back to the agent with a reason; it returns to draft | `Invoice.request_changes` |
| **Changes requested** | the status of a draft a human sent back | draft whose current revision has a `changes_requested` decision |
| **Reject** | refuse for good | `Invoice.reject` |
| **Withdraw** | the agent or its owner takes back an undecided proposal | `Invoice.withdraw` |
| **Cancel** | an approver cancels an approved invoice | `Invoice.cancel` |
| **Fingerprint** | the SHA-256 of the exact financial payload | `payload_hash` |

## Emotional goal

**Calm and trustworthy, not a trading terminal.** The user checks in for a few
minutes, understands *why* each invoice exists, and approves with confidence.
Avoid dense dashboards, heavy charts and noisy feeds.

## Defining experience: the review ("Quiet Ledger")

The chosen direction, among six explored, pairs a list with a reasoning pane:

- **Left:** a compact list of invoices awaiting approval. Each card shows the
  customer and amount, the proposing agent, the due date, and a one-line
  summary of the agent's reasoning.
- **Right:** the exact financial intent. It opens with one sentence, "What
  approving authorizes": *Acme Inc owes 1200.00 USDC, payable on Arbitrum One
  to 0x…, due 2026-11-04.* Below it come "Why this invoice exists" (the
  agent's reasoning and the agent's name), the lines and total, the customer,
  the destination with its network, rail and state, the revision number, the
  payload SHA-256 and, folded away, the canonical bytes that were hashed. Then
  the decision panel, then the technical details and the history.
- **One primary action per view: Approve.** The button names the amount
  ("Approve 1200.00 USDC") and the text above it says which revision and hash it
  authorizes and that nothing is issued yet. Request changes and Reject are
  outlined secondary buttons sharing one required reason field. Bulk "approve
  all" was considered and rejected: approval is authority, and authority is
  exercised one decision at a time.
- **No confirmation theatre.** There is no "are you sure?" dialog to click
  through on autopilot. The deliberate step is reading the summary sentence;
  the button repeats the amount.
- **What you see is what you approve.** The form submits the revision id and
  hash that were rendered. If the agent revised in the meantime, the human is
  told "This proposal changed while you were reviewing it. Nothing was
  decided" and shown the new revision.
- **Problems are flagged, not hidden.** A destination retired after submission
  shows a warning (`role="alert"`), and the Approve form is withheld; sending
  back remains available.
- **Operators see the same pane without decision controls**, with one line
  explaining that only an approver can decide. The page asks the domain
  (`Ash.can?`) instead of re-implementing the role rule.
- **The authority boundary is visible.** The review opens with "Proposed by
  *Billing agent*, an AI agent. It can prepare and submit; it cannot
  approve." next to "Decision authority: *You*, a human approver".
- **Hashes are present but quiet.** The decision says "You are approving
  revision 2 exactly as shown above"; the fingerprint is a short code below it,
  and the full hash and canonical bytes sit in Details.

## The rest of the workflow

- **Overview** leads with *Needs your attention* ("3 proposals are waiting for
  your decision", the oldest three, "Review the oldest"), then invoices by state
  (each opening the filtered list), then recent activity in sentences with
  named actors ("Billing agent submitted the invoice for Acme Inc for approval ·
  via mcp"). No charts: this is a workflow page, not BI.
- **Invoice list**: customer with the proposing agent beneath, amount, status,
  due date and *Next* ("Needs your review" with a Review button, "Agent to
  revise", "Waiting for an approver"). Filters: All, Needs review, Drafts,
  Approved, Rejected / cancelled.
- **Invoice page**: breadcrumb, status, a lifecycle strip
  (Draft → Pending approval → Approved, or the end actually reached) and a
  role-aware next step that says whose move it is.
- **Empty states** say what will appear and where it comes from ("Agents
  create invoice proposals through the REST API or MCP").

Responsive behaviour: split pane and full navigation from the `lg`
breakpoint; below it, list → detail with a back link, a grouped mobile menu,
and an "n to review" shortcut beside the menu button. Tables hide secondary
columns on narrow screens; nothing scrolls horizontally. (A sticky decision
footer on mobile is not done yet; the decision sits below the intent, by
design.)

## Visual language

- Palette "Mist & Slate" with a blue accent: mist `#f6f8fb / #eef2f7 / #e2e8f0`,
  slate `#4b5563 / #1f2937 / #111827`, primary `#2563eb`. Success `#22c55e`,
  warning `#f59e0b`, danger `#ef4444`.
- Status chips always combine text and colour: Pending approval (blue),
  Approved (green), Changes requested (amber), Rejected (red outline), Draft and
  Cancelled (neutral).
- Clean sans-serif type, an 8px grid, generous whitespace, soft shadows.
- The generated daisyUI theme (light and dark) is the base; the palette above
  belongs in the theme rather than in one-off classes.

## Interaction rules

- Forms are single-column, with visible labels and inline validation (AshPhoenix
  `validate` on change).
- Feedback is quiet: an immediate state change plus a toast. Errors say *what
  happened* and *what to do next*.
- Empty states have calm copy and a single call to action.
- Accessibility targets WCAG AA: touch targets ≥ 44px, visible focus, keyboard
  navigation, `role="alert"` for critical banners, status as text plus colour.
- Secrets are displayed once, in a dedicated notice that says so (as with the
  API key notice today).
