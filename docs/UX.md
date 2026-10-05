# UX direction

These decisions come from the original UX specification. The current screens are
the generated AshPhoenix LiveViews with Tauros navigation. The UX below applies
from Epic 3, when the approval inbox arrives.

## Emotional goal

**Calm and trustworthy, not a trading terminal.** The user checks in for a few
minutes, understands *why* each invoice exists, and approves with confidence.
Avoid dense dashboards, heavy charts and noisy feeds.

## Defining experience: the approval inbox ("Quiet Ledger")

The chosen direction, among six explored, pairs a list with a reasoning pane:

- **Left:** a compact list of invoices awaiting approval. Each card shows the
  customer and amount, the currency and a truncated destination (`0x5a…f2e`), the
  due date, and a one-line agent summary.
- **Right:** a *reasoning pane* headed "Why this invoice exists". It holds the
  agent's reasoning, the destination wallet account and its agent, any "needs
  review" flags, and then the actions.
- **One primary action per view: Approve invoice.** Secondary actions are Request
  changes and Reject. Bulk "approve all" was considered and rejected: approval
  is authority, and authority is exercised one decision at a time.
- **The inbox is the landing page** once invoices exist. The current dashboard
  is a placeholder for it.

Responsive behaviour: split pane on desktop; split or stacked on tablet; list →
detail with a sticky approval footer on mobile.

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
