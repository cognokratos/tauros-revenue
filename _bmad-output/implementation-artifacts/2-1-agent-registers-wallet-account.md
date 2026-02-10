# Story 2.1: Agent Registers Wallet Account

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an agent service,
I want to register a new wallet account using an Agent API key,
so that I can direct invoice payments to a public address.

## Acceptance Criteria

1. Given a valid `X-API-KEY` and a request with wallet name, public address, and currency, when the agent submits `POST /api/v1/accounts`, then a new Account is created and associated to the owning Agent.
2. Given a request missing any required account fields, when the request is processed, then the API responds with status 422 and `{error: %{code, message, details}}`, and no Account record is created.
3. Given an invalid or missing `X-API-KEY`, when the request is processed, then the API responds with status 401 and `{error: %{code, message, details}}`, and no Account record is created.
4. Given a valid request, when the Account is created, then the system stores only a public address (never private keys) and enforces `agent_id` scoping at the DB and context query level.

## Tasks / Subtasks

**Generator First (Required)**

- [ ] Use Phoenix generator to scaffold the baseline, then adapt:
  - [ ] Run: `mix phx.gen.json Wallets Account accounts wallet_name:string public_address:string currency:string agent_id:binary_id`
  - [ ] Review generated files and adjust to match agent-scoped API patterns and requirements below
- [ ] Data model + migration (adapt generated)
  - [ ] Ensure migration creates `accounts` table with `wallet_name`, `public_address`, `currency`, `agent_id` (FK to `agents`) and timestamps
  - [ ] Add index on `agent_id` and FK constraint for ownership
  - [ ] Do NOT allow private key fields
- [ ] Wallets context + schema (adapt generated)
  - [ ] Adjust `Tauros.Wallets` to accept `current_agent` and enforce scoping on all queries
  - [ ] Update schema/changeset to validate required fields (`wallet_name`, `public_address`, `currency`)
  - [ ] Remove `agent_id` from `cast` and set it programmatically from `current_agent` in context
- [ ] API endpoint (adapt generated)
  - [ ] Replace generated controller routes with agent-scoped API route: `POST /api/v1/accounts` under existing `:api_agent` pipeline
  - [ ] Implement `TaurosWeb.Api.Agent.AccountController.create/2` using `current_agent`
  - [ ] Return success JSON with account fields and standard REST error envelope on failure
- [ ] Tests
  - [ ] Controller tests: success, missing fields (422 envelope), missing/invalid API key (401 envelope)
  - [ ] Context tests: `create_account/2` enforces `agent_id` scoping and rejects missing fields
  - [ ] Add fixtures for accounts if helpful

## Developer Context (Do Not Skip)

- Existing agent auth is in `TaurosWeb.AgentAuth`. It assigns `:current_agent` on the conn for `:api_agent` routes using the `X-API-KEY` header. Do not re-implement auth in controllers; use the pipeline.  
- Admin APIs already use the REST error envelope `{error: %{code, message, details}}`. Follow the same error format here for consistency.  
- Current patterns: Admin controllers use `action_fallback` and JSON views; the agent test controller returns raw JSON. Choose one approach and keep it consistent with existing agent APIs.
- The generator will create public REST routes and controllers; you must replace those with agent-scoped endpoints under `/api/v1` and remove any unused public routes.
- Regression guardrail: do not modify existing admin routes or auth pipelines while adding the agent account endpoint.

## Technical Requirements

- **Auth:** `X-API-KEY` header required for `/api/v1/accounts` (agent/service auth).
- **Data fields:** `wallet_name`, `public_address`, `currency`, `agent_id`.
- **Security:** Never accept or persist private keys; only public addresses.
- **Scoping:** All account writes and reads must be scoped to the owning agent.
- **Error format:** REST errors must return `{error: %{code, message, details}}` with status 401 or 422 as appropriate.

## Architecture Compliance

- Use Phoenix 1.8 + LiveView 1.1 patterns and Ecto contexts as the source of truth for writes/reads.  
- Keep API logic in controllers; all persistence in context functions.  
- Enforce `agent_id` scoping at DB level (FK + constraints) and in context queries.  
- Follow the project structure: contexts under `lib/tauros/`, web controllers under `lib/tauros_web/controllers/`.
- Follow naming conventions from architecture: tables are plural snake_case (e.g., `accounts`), columns are snake_case (e.g., `agent_id`).
- REST errors must use the standard envelope `{error: %{code, message, details}}` across all agent endpoints.

## Library / Framework Requirements (Current + Latest)

- Project versions in `mix.exs`: `phoenix ~> 1.8.3`, `phoenix_live_view ~> 1.1.0`, `ecto_sql ~> 3.13`, `req ~> 0.5`, `bandit ~> 1.5`.
- Stay on the versions pinned in `mix.exs` unless explicitly directed to upgrade.

## File Structure Requirements

- `lib/tauros/wallets.ex` (context)
- `lib/tauros/wallets/account.ex` (schema + changeset)
- `lib/tauros_web/controllers/api/agent/account_controller.ex` (API controller)
- `lib/tauros_web/router.ex` (route under `/api/v1`)
- `priv/repo/migrations/*_create_accounts.exs` (migration)
- `test/tauros_web/controllers/api/agent/account_controller_test.exs` (controller tests)
- `test/tauros/wallets_test.exs` and `test/support/fixtures/wallets_fixtures.ex` (context tests + fixtures)

## Testing Requirements

- Use `ConnCase` for controller tests and `DataCase` for context tests.
- Use fixtures (`AgentsFixtures`) to create an agent and a plaintext API key for tests.
- Assert JSON responses via `json_response/2` and ensure error envelope shape.
- Avoid `Process.sleep/1`; prefer deterministic assertions.

## Project Context Reference (Rules to Obey)

- Use `Req` for HTTP calls if needed; do not add other HTTP clients.
- Never access `@current_user`; use `@current_scope.user` in LiveViews (not applicable here but critical globally).
- Do not use `<.flash_group>` outside `layouts.ex`.
- Always enforce `agent_id` scoping at DB and context query level.
- Do not cast programmatic fields like `agent_id`; set them explicitly in the context.
- Scope boundary: do not add account list/show endpoints or any LiveView UI in this story; only implement `POST /api/v1/accounts`.

## References

- `_bmad-output/planning-artifacts/epics.md#Story 2.1`
- `_bmad-output/planning-artifacts/prd.md#API Backend Specific Requirements`
- `_bmad-output/planning-artifacts/architecture.md#API & Communication Patterns`
- `_bmad-output/project-context.md#Critical Implementation Rules`
- `lib/tauros_web/agent_auth.ex`
- `lib/tauros_web/router.ex`

## Story Completion Status

Status set to **ready-for-dev**. Ultimate context engine analysis completed - comprehensive developer guide created.

## Dev Agent Record

### Agent Model Used

GPT-5 (Codex CLI)

### Debug Log References

### Completion Notes List

- Note: This is the first story in Epic 2, so there are no prior story learnings to apply.

### File List
