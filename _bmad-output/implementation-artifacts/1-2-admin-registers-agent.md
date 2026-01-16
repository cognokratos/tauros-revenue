# Story 1.2: Admin Registers Agent

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin user,
I want to register a new Agent with a name and API key,
so that the Agent can act on behalf of the admin in operational flows.

## Acceptance Criteria

1. Given a valid Bearer token and a request with a name for a new Agent, when the admin submits the create-agent request, then a new Agent is created and the API key is stored hashed at rest.
2. Given a valid Bearer token and a request with a name for a new Agent, when the request succeeds, then the API returns a success response that includes the generated API key for immediate use by the agent.
3. Given a request missing required Agent fields, when the request is processed, then the API responds with `{error: %{code, message, details}}` and no Agent record is created.
4. Given an invalid or missing Bearer token, when the request is processed, then the API responds with status 401 and the standardized error envelope.
5. Given an authenticated admin in the LiveView UI, when they navigate to Agents, then they can view a list of Agents scoped to their user.
6. Given an authenticated admin in the LiveView UI, when they submit the add-agent form with a valid name, then the Agent is created and the generated API key is shown once.
7. Given an authenticated admin in the LiveView UI, when the add-agent form is missing required fields, then the UI shows validation errors and does not create an Agent.

## Tasks / Subtasks

- [ ] Add Agents context, schema, and migration
  - [ ] Create `agents` table with `name`, `api_key_hash`, `user_id`, timestamps
  - [ ] Add DB constraints (not null on `name`, `api_key_hash`, `user_id`)
  - [ ] Add indexes as needed (at minimum `user_id`)
- [ ] Prefer generators first, then customize
  - [ ] Use Phoenix generators to scaffold context, schema, migration, LiveView, and API, then update the generated code to match this story
  - [ ] Keep generator output changes minimal and focused on requirements
- [ ] Implement Agents context functions
  - [ ] `Agents.create_agent/2` accepts `current_scope` and params, generates API key, stores hash, and associates the admin user
  - [ ] Ensure `user_id` is set programmatically (not via `cast`)
  - [ ] Return the generated API key only once in the response payload
- [ ] Add admin REST endpoint
  - [ ] Add `POST /api/admin/v1/agents` under the existing `:api_admin` pipeline
  - [ ] Controller action uses `current_scope.user` for ownership and returns JSON payload
  - [ ] Error responses use `{error: %{code, message, details}}`
- [ ] Add LiveView UI for Agents
  - [ ] Add Agents LiveView routes under `live_session :require_authenticated_user` (requires login and ensures `current_scope` is assigned)
  - [ ] Provide index view listing Agents scoped to `current_scope.user`
  - [ ] Provide a form to create an Agent using `<.form for={@form}>` and `<.input>`; show generated API key once on success
  - [ ] Use `stream/3` for the Agents list and `phx-update="stream"` in the template
- [ ] Tests
  - [ ] Successful create returns 201 (or 200) with API key and agent data
  - [ ] Missing name returns 422 with error envelope
  - [ ] Missing/invalid Bearer token returns 401 with error envelope
  - [ ] API key stored hashed (never store or return hashed value)
  - [ ] LiveView list renders with empty state and with agents
  - [ ] LiveView create validates required fields and shows API key only once
  - [ ] Regression: existing admin auth/login behavior from Story 1.1 remains unchanged

## Dev Notes

- Admin auth is already enforced in `lib/tauros_web/router.ex` via the `:api_admin` pipeline and `require_admin_api_token/2`.
- Reuse `Accounts.fetch_user_by_api_token/1` for Bearer token auth and `Scope.for_user/1` for assigning `current_scope`.
- API keys must be hashed at rest; do not store or log plaintext beyond the creation response.
- Follow REST error envelope standard: `{error: %{code, message, details}}`.
- Admin endpoints are versioned under `/api/admin/v1`.
- LiveView routes that require login must live under the existing `live_session :require_authenticated_user` block to ensure `current_scope` is assigned.
- LiveView templates must start with `<Layouts.app flash={@flash} ...>` and pass `current_scope`.
- Do not call Repo directly from controllers or LiveViews; use context functions only.
- Check for existing hashing/encryption helpers in the codebase and reuse if present.
- This project uses binary IDs; keep generator output aligned with existing ID types and conventions.

### Generator-First Implementation Plan

Use the Phoenix generators first for context, schema, migration, LiveView, and HTML templates, then update the generated code to satisfy this story’s requirements.

1. Generate context, schema, and migration:
   - `mix phx.gen.context Agents Agent agents name:string api_key_hash:string user_id:references:users`
2. Generate LiveView UI for Agents (index + new):
   - `mix phx.gen.live Agents Agent agents name:string`
3. Generate a JSON controller for admin API:
   - `mix phx.gen.json Agents Agent agents name:string api_key_hash:string user_id:references:users`

After generation:
- Update the migration to match constraints (`name`, `api_key_hash`, `user_id` not null) and add the `user_id` index if not present.
- Ensure `user_id` is set programmatically (do not `cast` it).
- Replace any plaintext API key usage with a generated key that is hashed at rest and only returned once.
- Adjust LiveView to:
  - live under `live_session :require_authenticated_user` (required to assign `current_scope`)
  - use `stream/3` and `phx-update="stream"`
  - render with `<Layouts.app flash={@flash} current_scope={@current_scope}>`
  - show the generated API key once on success
- Adjust admin API routes to live under:
  - `scope "/api/admin", TaurosWeb.Api.Admin do`
  - `pipe_through :api_admin`
  - `post "/v1/agents", AgentController, :create`
  - This is required because the route must use the admin Bearer-token auth pipeline.

## Developer Context

This story builds on the admin Bearer-token authentication added in Story 1.1. Use the existing admin API pipeline and error envelope behavior; do not add new auth plugs. Agents must be owned by the authenticated admin user and scoped via `current_scope.user` to support downstream ownership constraints.

## Technical Requirements

- Endpoint: `POST /api/admin/v1/agents`
- Auth: `Authorization: Bearer <token>`; reject missing/invalid tokens with 401 and error envelope
- Data: store `api_key_hash` (hashed) and `user_id` for ownership
- API key handling: generate a secure random API key, return it once on create, and never persist plaintext
- Context rules: all data writes through context functions; no direct repo usage from controllers
- UI: Agents LiveView (index + new form) under authenticated session; show API key once on create
- UX: keep UI calm and scannable; include empty state, success feedback, and validation errors inline

## Architecture Compliance

- Enforce admin auth in router pipeline (no controller-level auth)
- Keep REST error envelope consistent with `{error: %{code, message, details}}`
- Respect context boundaries (web layer calls contexts only)
- Maintain `agent_id` scoping patterns for downstream entities (customers/accounts/invoices)
- LiveView lists use streams; templates wrap with `<Layouts.app>`
- Use snake_case for files, modules, and JSON fields; keep naming consistent with existing conventions

## Library & Framework Requirements

- Phoenix 1.8 / LiveView 1.1 / Ecto 3.13
- Use `Req` for HTTP calls if any are needed (none expected in this story)
- Avoid adding new dependencies unless required for encryption/hash support

## File Structure Requirements

- Context: `lib/tauros/agents/`
- Schema: `lib/tauros/agents/agent.ex`
- Context module: `lib/tauros/agents.ex`
- Controller: `lib/tauros_web/controllers/api/admin/agent_controller.ex`
- Router: `lib/tauros_web/router.ex`
- LiveView: `lib/tauros_web/live/agents_live/index.ex` and `lib/tauros_web/live/agents_live/index.html.heex`
- Tests: `test/tauros_web/controllers/api/admin/`, `test/tauros/agents/`, `test/tauros_web/live/agents_live/`

## Testing Requirements

- Controller tests must assert status codes and error envelope shape (401, 422, success)
- Verify `current_scope.user` is required and respected
- Verify API key is not persisted in plaintext (hash exists, plaintext not stored)
- LiveView tests must use element IDs and `Phoenix.LiveViewTest` helpers (no raw HTML asserts)
- Regression tests: confirm existing admin auth/login endpoints still return expected error envelopes and status codes

## Previous Story Intelligence

- Story 1.1 established the `:api_admin` pipeline and JSON error envelopes for Bearer token auth.
- `TaurosWeb.UserAuth.require_admin_api_token/2` already assigns `current_scope` or halts with 401 and error envelope.
- Reuse the existing auth behavior; do not introduce duplicate or conflicting auth plugs.

## Git Intelligence Summary

Recent commits indicate admin auth and sprint planning were just added. Align naming and error handling with those changes to avoid regressions:
- `feat: story 1.1 (#1)`
- `chore: sprint planning`

## Latest Tech Information

No external web research performed due to restricted network access. Use the versions and patterns defined in project context and architecture documents.

## Project Context Reference

Key rules to follow:
- Use `current_scope.user` in controllers and templates (never `@current_user`).
- REST errors must use `{error: %{code, message, details}}`.
- Use contexts for writes; no direct schema writes from controllers.
- API keys and PII must be encrypted/hashed at rest (avoid plaintext storage).

## Story Completion Status

Status: ready-for-dev
Completion note: Ultimate context engine analysis completed - comprehensive developer guide created.

### Completion Verification Checklist

- Admin API: create agent returns API key once and stores only hash
- Admin API: error envelopes and status codes match existing standards
- LiveView UI: Agents list and create flows work with `current_scope.user`
- LiveView UI: empty state, success feedback, and validation errors are visible

## References

- `_bmad-output/planning-artifacts/epics.md#Story 1.2`
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
