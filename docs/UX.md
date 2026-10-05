# UX direction

These decisions come from the original UX specification. Most screens are the
generated AshPhoenix LiveViews with Tauros navigation. The approval inbox
(`/approvals`, `TaurosWeb.ApprovalLive`) is the first purpose-built screen and
follows the direction below.

## Emotional goal

**Calm and trustworthy, not a trading terminal.** The user checks in for a few
minutes, understands *why* each invoice exists, and approves with confidence.
Avoid dense dashboards, heavy charts and noisy feeds.

## Defining experience: the approval inbox ("Quiet Ledger")

The chosen direction, among six explored, pairs a list with a reasoning pane:

- **Left:** a compact list of invoices awaiting approval. Each card shows the
  customer and amount, the currency and a truncated destination (`0x5a…f2e`), the
  due date, and a one-line agent summary.
- **Right:** the exact financial intent. It opens with one sentence, "What
  approving authorizes": *Acme Inc owes 1200.00 USDC, payable on Arbitrum One
  to 0x…, due 2026-11-04.* Below it come "Why this invoice exists" (the
  agent's reasoning and the agent's name), the lines and total, the customer,
  the destination with its network, rail and state, the revision number, the
  payload SHA-256 and, folded away, the canonical bytes that were hashed. Then
  the decision panel, then the history.
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
- **The dashboard points to the inbox** when proposals are waiting. Making the
  inbox the landing page is still open.

Responsive behaviour: split pane from the `lg` breakpoint; below it, list →
detail with a back link. (A sticky approval footer on mobile is not done yet.)

## Visual language

- Palette "Mist & Slate" with a blue accent: mist `#f6f8fb / #eef2f7 / #e2e8f0`,
  slate `#4b5563 / #1f2937 / #111827`, primary `#2563eb`. Success `#22c55e`,
  warning `#f59e0b`, danger `#ef4444`.
- Status chips always combine text and colour: Pending (blue), Approved (green),
  Needs review (amber).
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
