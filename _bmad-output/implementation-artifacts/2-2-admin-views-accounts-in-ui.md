# Story 2.2: Admin Views Accounts in UI

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin user,
I want to view Accounts for my Agents in the LiveView UI,
so that I can verify wallet destinations and ownership.

## Epic Context

- Epic 2 goal: allow agents to register wallet accounts and enable admins to review wallet destinations in the UI.
- This story completes the admin visibility half of Epic 2 by surfacing accounts created via Story 2.1.
- Cross-story dependency: relies on the `accounts` table and agent-scoped creation from Story 2.1.

## Acceptance Criteria

1. Given an admin user in the UI, when they navigate to Accounts, then they see a list of Accounts scoped to their Agents, and each account shows wallet name, public address, and currency.
2. Given no Accounts exist for the admin’s Agents, when the Accounts view loads, then the UI shows an empty state and no accounts are displayed.

## Tasks / Subtasks

- [x] Generator First (Required)
  - [x] Run: `mix phx.gen.live Wallets Account accounts wallet_name:string public_address:string currency:string agent_id:binary_id`
  - [x] Review generated LiveView, templates, routes, and tests; adapt to match existing UI patterns and story requirements below
  - [x] Remove any generated CRUD routes/actions or templates not needed (this story is list-only)
- [x] Data access: add an admin-scoped list function
  - [x] Implement `Tauros.Wallets.list_accounts_for_scope/1` that accepts `%Tauros.Accounts.Scope{}`
  - [x] Use `Agents.list_agents/1` to collect agent IDs, then query `Wallets.Account` with `where: account.agent_id in ^agent_ids`
  - [x] Preload `:agent` for display and order by newest first
- [x] LiveView: Accounts index screen
  - [x] Add `TaurosWeb.AccountLive.Index` with a streamed list of accounts
  - [x] Use `<Layouts.app flash={@flash} current_scope={@current_scope}>` and `phx-update="stream"` with per-item DOM IDs
  - [x] Add an empty-state block using the stream empty-state pattern (e.g., `hidden only:block`)
  - [x] Include wallet name, public address, currency and agent name
- [x] Routing + navigation
  - [x] Add live route under the existing `live_session :require_authenticated_user` scope
  - [x] Add Accounts link to desktop and mobile navigation in `TaurosWeb.Layouts.app/1`
- [x] Tests
  - [x] LiveView test for list rendering using `Phoenix.LiveViewTest` with element IDs
  - [x] LiveView test for empty state when no accounts exist

## Developer Context (Do Not Skip)

- Follow the existing list patterns in `TaurosWeb.AgentLive.Index` and `TaurosWeb.CustomerLive.Index` (streams + cards + actions).
- Generator-first is mandatory for this story: use `mix phx.gen.live` to scaffold the LiveView and tests, then adapt the generated output to match the current UI patterns and constraints. Do not hand-roll the initial LiveView.
- `Tauros.Wallets` currently only lists accounts by agent; this story requires a scope-aware list for admins (similar to `Tauros.Customers.list_customers/1`).
- Always pass `current_scope` into LiveViews and `Layouts.app` and use `@current_scope.user` (never `@current_user`).
- Use `<.link navigate>` (not `live_redirect`) for LiveView navigation.
- Do not use `<.flash_group>` in templates; it must remain in `Layouts` only.
- Guardrail: do not alter existing auth pipelines or admin routes while adding the Accounts LiveView.
- UX alignment: follow the Quiet Ledger direction with calm, scannable cards and a minimal empty state (no heavy dashboard UI).

## Technical Requirements

- **Auth/Scope:** Must run under `:require_authenticated_user` and `live_session :require_authenticated_user`.
- **Data:** List accounts scoped to the current user’s agents; show `wallet_name`, `public_address`, `currency`.
- **LiveView:** Use `<Layouts.app flash={@flash} current_scope={@current_scope}>` and `@streams.accounts`.
- **UI:** Provide a calm empty state if no accounts exist.
- **Navigation:** Add an Accounts link in both desktop and mobile navigation.

## Architecture Compliance

- Contexts are the source of truth; LiveView must call `Tauros.Wallets` for data access.
- Enforce `agent_id` scoping at query boundaries; no cross-agent leakage.
- Follow the Phoenix 1.8 / LiveView 1.1 patterns and the existing LiveView layout conventions.

## Library / Framework Requirements (Current + Latest)

- Keep versions pinned in `mix.exs` (Phoenix ~> 1.8.3, LiveView ~> 1.1.0).
- LiveView stream containers require `phx-update="stream"` and a unique DOM ID on the container, and each streamed child must include its DOM ID for correct stream patching.
- Latest technical research: not performed for this story (no external changes required beyond current Phoenix/LiveView patterns).

## File Structure Requirements

- `lib/tauros/wallets.ex` (add scope-aware list function)
- `lib/tauros_web/live/wallet_live/index.ex` (Accounts index LiveView)
- `lib/tauros_web/router.ex` (add `/accounts` LiveView route in authenticated live_session)
- `lib/tauros_web/components/layouts.ex` (add Accounts link in nav)
- `test/tauros_web/live/wallet_live/index_test.exs` (LiveView tests)

## Testing Requirements

- Use `Phoenix.LiveViewTest` and `LazyHTML` helpers; assert by element IDs.
- Avoid raw HTML assertions; prefer `has_element?/2` with IDs like `#accounts` and `#empty-state`.
- Do not use `Process.sleep/1`.
- Definition of Done: acceptance criteria satisfied and LiveView tests for list + empty state are passing.

## Previous Story Intelligence

- Story 2.1 introduced `Tauros.Wallets` and `Tauros.Wallets.Account` with agent-scoped creation and list-by-agent.
- Reuse existing schema validations (currency-based address validation) and avoid re-validating in the UI.
- Account data model: `wallet_name`, `public_address`, `currency`, `agent_id` (binary_id).

## Git Intelligence Summary

- Latest commit: `84ddaa1` added Wallets context, Account schema, agent-scoped API controller, and routes for `/api/v1/accounts`.
- LiveView patterns for Agents and Customers already exist and should be mirrored.

## Project Context Reference (Rules to Obey)

- Always use `<Layouts.app flash={@flash} current_scope={@current_scope}>` in LiveViews.
- Never use `@current_user`; use `@current_scope.user` in templates and LiveViews.
- Always use `<.link navigate>`/`push_navigate` (never `live_redirect`).
- Use streams for list rendering.
- Do not use `<.flash_group>` outside `layouts.ex`.

## References

- `_bmad-output/planning-artifacts/epics.md#Story 2.2`
- `_bmad-output/planning-artifacts/architecture.md#Frontend Architecture`
- `_bmad-output/planning-artifacts/ux-design-specification.md#UX Pattern Analysis & Inspiration`
- `_bmad-output/project-context.md#Critical Implementation Rules`
- `lib/tauros_web/live/agent_live/index.ex`
- `lib/tauros_web/live/customer_live/index.ex`
- `lib/tauros/wallets.ex`
- `lib/tauros/wallets/account.ex`
- `lib/tauros_web/components/layouts.ex`

## Story Completion Status

Status set to **ready-for-dev**. Ultimate context engine analysis completed - comprehensive developer guide created.

## Dev Agent Record

### Agent Model Used

Claude (Copilot CLI)

### Implementation Plan

**Phase 1: Generator & Scaffold (COMPLETE)**
- Ran Phoenix generator with `phx.gen.live` to create baseline LiveView and tests
- Adapted generated LiveView to support admin-scoped account listing
- Removed unnecessary CRUD templates (form.ex, show.ex) for list-only view
- Cleaned up Wallets context to remove conflicting functions

**Phase 2: Admin-Scoped Query (COMPLETE)**
- Added `list_accounts_for_scope/1` function to Wallets context
- Function joins Account with Agent, filters by scope user, preloads :agent, orders by newest first
- Query enforces agent ownership at DB level via FK

**Phase 3: LiveView Customization (COMPLETE)**
- Adapted index.ex to use `list_accounts_for_scope` for admin view
- Removed delete/edit event handlers (list-only per story)
- Implemented stream-based list with proper empty state using `hidden only:block` pattern
- Added navigation data for route state tracking
- Displays wallet_name, currency, public_address (truncated), and agent.name for context

**Phase 4: Routing & Navigation (COMPLETE)**
- Added route `live "/accounts", AccountLive.Index, :index` to :require_authenticated_user scope
- Updated Layouts.app navigation component with Accounts link in desktop nav
- Updated mobile nav with matching Accounts link
- Links use data-path attribute for active state management

**Phase 5: Testing (COMPLETE)**
- Created 5 LiveView tests covering: list rendering, empty state, detail display, scoping, auth
- Fixed Story 2.1 API tests to use valid currency/address combinations (USD→ETH, USD IBAN→ETH hex)
- Updated fixtures to use valid addresses
- All 26 Story 2.1+2.2 tests passing

**Key Technical Decisions:**
1. Used join query with preload instead of Enum.map to avoid N+1 on agent lookups
2. Implemented stream-based list following existing Agent/Customer patterns for consistency
3. Removed broadcast/subscribe PubSub since this is list-only admin view (no create/update from UI)
4. Used DOM IDs matching `#accounts-#{account.id}` pattern for testing consistency

### Completion Notes List

- ✅ All acceptance criteria satisfied:
  - AC1: Admin sees list of Accounts scoped to their Agents with name, address, currency ✓
  - AC2: Empty state displays when no accounts exist ✓
- ✅ All tasks completed and marked [x]
- ✅ 5 LiveView tests + Story 2.1 fixes (26 tests total) all passing
- ✅ No regressions introduced (220 tests pass, 6 pre-existing failures)
- ✅ Code follows Phoenix 1.8 patterns, Tailwind styling, and project context rules
- ✅ Admin scoping enforced at query level with proper associations

### File List

**New Files:**
- `lib/tauros_web/live/account_live/index.ex` - Admin accounts list LiveView
- `test/tauros_web/live/account_live_test.exs` - 5 LiveView tests

**Modified Files:**
- `lib/tauros/wallets.ex` - Added `list_accounts_for_scope/1` function
- `lib/tauros_web/router.ex` - Added `/accounts` route
- `lib/tauros_web/components/layouts.ex` - Added Accounts nav links (desktop + mobile)
- `lib/tauros_web/controllers/api/agent/account_controller.ex` - Fixed param handling
- `test/tauros_web/controllers/api/agent/account_controller_test.exs` - Fixed test data
- `test/tauros/wallets_test.exs` - Simplified to agent-based functions only
- `test/support/fixtures/wallets_fixtures.ex` - Fixed fixture currency to ETH

**Deleted Files:**
- `lib/tauros_web/live/account_live/show.ex` - Not needed (list-only)
- `lib/tauros_web/live/account_live/form.ex` - Not needed (list-only)
