# Story 1.3: Admin Registers Customer

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin user,
I want to register a new Customer with name and email,
so that the Agent can create invoices for that customer.

## Acceptance Criteria

1. Given a valid Bearer token and a request with customer name, email, and agent_id, when the admin submits the create-customer request, then a new Customer is created and associated with the owning Agent.
2. Given a request missing required Customer fields, when the request is processed, then the API returns a standardized `{error: %{code, message, details}}` and no Customer record is created.
3. Given an invalid or missing Bearer token, when the request is processed, then the API returns status 401 with the standardized error envelope.
4. Given an authenticated admin in the LiveView UI, when they navigate to Customers, then they can view a list of Customers scoped to Agents they own.
5. Given an authenticated admin in the LiveView UI, when they submit the add-customer form with valid name, email, and agent selection, then the Customer is created and shown in the list.
6. Given an authenticated admin in the LiveView UI, when the add-customer form is missing required fields, then the UI shows validation errors and does not create a Customer.

## Tasks / Subtasks

- [ ] Generator-first: scaffold, then customize
  - [ ] Generate context, schema, and migration
  - [ ] Generate LiveView UI for Customers
  - [ ] Generate JSON controller for admin API
- [ ] Add Customers context, schema, and migration (post-gen updates)
  - [ ] Create `customers` table with `name`, `email`, `agent_id`, timestamps
  - [ ] Add DB constraints (not null on `name`, `email`, `agent_id`) and index `agent_id`
  - [ ] Encrypt PII fields at rest (at minimum `email`; follow existing encryption patterns)
- [ ] Implement Customers context functions
  - [ ] `Customers.create_customer/2` accepts `current_scope` and params, sets `agent_id` programmatically
  - [ ] Enforce agent ownership: ensure `agent_id` belongs to `current_scope.user`
  - [ ] Provide list functions scoped by `current_scope.user` (for UI and API)
- [ ] Add admin REST endpoint
  - [ ] Add `POST /api/admin/v1/customers` under existing `:api_admin` pipeline
  - [ ] Controller uses `current_scope.user` and calls context only (no direct Repo usage)
  - [ ] Error responses use `{error: %{code, message, details}}`
- [ ] Add LiveView UI for Customers
  - [ ] Add Customers LiveView routes under existing `live_session :require_authenticated_user`
  - [ ] Index view lists Customers scoped to `current_scope.user`
  - [ ] Provide a form to create a Customer using `<.form for={@form}>` and `<.input>`
  - [ ] Use `stream/3` for the Customers list and `phx-update="stream"` in the template
- [ ] Tests
  - [ ] API: success returns 201/200 with customer data
  - [ ] API: missing required fields returns 422 with error envelope
  - [ ] API: missing/invalid Bearer token returns 401 with error envelope
  - [ ] Context: customer is associated to agent owned by `current_scope.user`
  - [ ] LiveView: list renders empty state and customers
  - [ ] LiveView: create validates required fields and shows errors

## Dev Notes

- Admin auth is already enforced in `lib/tauros_web/router.ex` via the `:api_admin` pipeline and `require_admin_api_token/2`.
- Use `current_scope.user` for ownership checks and scoping; never rely on `@current_user`.
- Customer ownership is via `agent_id`; enforce that the selected Agent belongs to the current user.
- Use contexts for all writes; do not call Repo directly from controllers or LiveViews.
- LiveView templates must start with `<Layouts.app flash={@flash} current_scope={@current_scope}>`.
- Use `<.form>` and `<.input>` and assign forms via `to_form/2`.
- Prefer generators first, then customize to align with this story’s requirements.
- Reuse existing admin API error helpers and auth patterns from Story 1.1/1.2:
  - `TaurosWeb.UserAuth.require_admin_api_token/2`
  - `TaurosWeb.ErrorJSON` error envelope handling
- Reuse the LiveView list + form patterns from `lib/tauros_web/live/agent_live/` to avoid duplicate UI logic.

## Developer Context

This story extends the admin setup foundation. It should follow the same admin Bearer token auth, error envelope, and context boundaries as Story 1.1/1.2. Customer creation must respect agent ownership and `agent_id` scoping at both the DB and context query level.
Dependencies: Agents must exist before Customers can be created; assume Story 1.2 is complete and use the Agents context to populate agent selection.

## Technical Requirements

- Endpoint: `POST /api/admin/v1/customers`
- Auth: `Authorization: Bearer <token>`; reject missing/invalid tokens with 401 and error envelope
- Data: store `name`, `email`, `agent_id` and associate Customer to owning Agent
- Ownership: verify `agent_id` belongs to `current_scope.user` before create
- Security: encrypt PII at rest (email; follow existing patterns for PII)
- Error handling: REST error envelope `{error: %{code, message, details}}`
- UI: Customers LiveView under authenticated session; list and create flows with stream-based list
- UX detail: follow the "Quiet Ledger" pattern—compact, scannable list of customers with a focused create form; keep actions minimal and avoid dense dashboards.
- Performance: keep queries scoped by `current_scope.user` and preload needed associations to avoid N+1 in list views

## Architecture Compliance

- Enforce `agent_id` scoping in context queries and DB constraints
- Respect admin vs agent/service auth separation
- Keep contexts as source of truth across API and LiveView
- REST errors must use the standardized error envelope

## Library & Framework Requirements

- Phoenix 1.8 / LiveView 1.1 / Ecto 3.13
- Use `Req` for HTTP calls if needed (none expected here)
- Avoid adding new dependencies unless required for encryption

## File Structure Requirements

- Context: `lib/tauros/customers/`
- Schema: `lib/tauros/customers/customer.ex`
- Context module: `lib/tauros/customers.ex`
- Controller: `lib/tauros_web/controllers/api/admin/customer_controller.ex`
- Router: `lib/tauros_web/router.ex`
- LiveView: `lib/tauros_web/live/customers_live/index.ex` and `lib/tauros_web/live/customers_live/index.html.heex`
- Tests: `test/tauros_web/controllers/api/admin/`, `test/tauros/customers/`, `test/tauros_web/live/customers_live/`

## Testing Requirements

- Controller tests must assert status codes and error envelope shape (401, 422, success)
- Verify `current_scope.user` scoping and agent ownership enforcement
- LiveView tests must use element IDs and `Phoenix.LiveViewTest` helpers (no raw HTML asserts)
- Ensure no regressions in admin auth flows from Story 1.1/1.2
- Include a regression test that ensures agent ownership is enforced when an admin tries to create a Customer for another admin’s Agent

## Generator-First Implementation Plan

Use Phoenix generators first for context, schema, migration, LiveView, and JSON API, then adapt the output to match this story.

1. Generate context, schema, and migration:
   - `mix phx.gen.context Customers Customer customers name:string email:string agent_id:references:agents`
2. Generate LiveView UI for Customers (index + new):
   - `mix phx.gen.live Customers Customer customers name:string email:string agent_id:references:agents`
3. Generate JSON controller for admin API:
   - `mix phx.gen.json Customers Customer customers name:string email:string agent_id:references:agents`

After generation:
- Update the migration to enforce NOT NULL constraints on `name`, `email`, `agent_id` and add an index on `agent_id`.
- Ensure `agent_id` is set programmatically in context functions (do not `cast` it).
- Enforce ownership by verifying `agent_id` belongs to `current_scope.user` before create.
- Route LiveViews under existing `live_session :require_authenticated_user`.
- Route API under `:api_admin` pipeline with `POST /api/admin/v1/customers`.
- Use `<Layouts.app ... current_scope={@current_scope}>`, streams for lists, and `<.form>`/`<.input>` in templates.
- Scope boundary: no new UI beyond Customers list + create form; do not add edit/delete flows unless required later.

## Previous Story Intelligence

- Story 1.1 established `:api_admin` pipeline and JSON error envelopes for Bearer token auth.
- Story 1.2 implemented Agents context, admin API endpoint, and LiveView patterns using streams.
- Reuse these patterns for Customers to avoid regressions and keep UI/API consistent.
- File patterns to mirror: `lib/tauros/agents.ex`, `lib/tauros/agents/agent.ex`, `lib/tauros_web/controllers/api/admin/agent_controller.ex`,
  `lib/tauros_web/live/agent_live/index.ex`, `lib/tauros_web/live/agent_live/form.ex`, `lib/tauros_web/live/agent_live/show.ex`,
  `test/tauros_web/controllers/api/admin/agent_controller_test.exs`, `test/tauros_web/live/agent_live_test.exs`

## Git Intelligence Summary

Recent commits indicate admin auth and Agents functionality were added and follow these patterns:
- `feat: story 1.1 (#1)`
- `Story 1.2 (#2)`
- `chore: sprint planning`

Follow the established file locations, router scopes, and error handling conventions from those commits.

## Latest Tech Information

No external web research performed due to restricted network access. Use the versions and patterns defined in project context and architecture documents.

## Project Context Reference

Key rules to follow:
- Use `current_scope.user` in controllers and templates (never `@current_user`).
- REST errors must use `{error: %{code, message, details}}`.
- Use contexts for writes; no direct schema writes from controllers.
- PII must be encrypted at rest; avoid storing plaintext beyond necessary processing.
- LiveView templates must start with `<Layouts.app ...>` and pass `current_scope`.

## Story Completion Status

Status: ready-for-dev
Completion note: Ultimate context engine analysis completed - comprehensive developer guide created.

### Completion Verification Checklist

- [ ] Admin API: create customer returns 201/200 with customer data
- [ ] Admin API: error envelopes and status codes match existing standards
- [ ] Admin API: ownership enforced (agent belongs to current user)
- [ ] LiveView UI: Customers list renders with user scoping
- [ ] LiveView UI: create form validates required fields and shows errors
- [ ] No regressions in admin auth/login endpoints

## References

- `_bmad-output/planning-artifacts/epics.md#Story 1.3`
- `_bmad-output/planning-artifacts/prd.md#API Backend Specific Requirements`
- `_bmad-output/planning-artifacts/architecture.md#Authentication & Security`
- `_bmad-output/planning-artifacts/architecture.md#API & Communication Patterns`
- `_bmad-output/planning-artifacts/ux-design-specification.md#Core User Experience`
- `_bmad-output/project-context.md#Critical Implementation Rules`
- `lib/tauros_web/router.ex`
- `lib/tauros_web/user_auth.ex`

## Dev Agent Record

### Agent Model Used

GPT-5 (Codex CLI)

### Debug Log References

### Completion Notes List

### File List
