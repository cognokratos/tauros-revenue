# Story 1.1: Admin Authentication for Admin Endpoints

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin user,
I want to authenticate with a Bearer token for admin endpoints,
so that only authorized admins can manage core resources.

## Acceptance Criteria

1. Given an admin request to `/api/admin/v1/*` without a valid Bearer token, when the request is processed, then the API responds with status 401 and `{error: %{code, message, details}}`, and no protected action is performed.
2. Given an admin request with a valid Bearer token, when the request is processed, then the request is authorized and the controller receives a `current_scope` with `current_scope.user` present.
3. Given an admin request with a malformed `Authorization` header or non-Bearer scheme, when the request is processed, then the API responds with status 401 and `{error: %{code, message, details}}`.
4. Given an admin login request to `POST /api/admin/v1/login` with a valid email and password, when the request is processed, then the API responds with status 200 and `{data: %{token: "Bearer <token>"}}`.
5. Given an admin login request with invalid credentials, when the request is processed, then the API responds with status 401 and `{error: %{code, message, details}}`.
6. Given an admin login request with missing or invalid parameters, when the request is processed, then the API responds with status 422 and `{error: %{code, message, details}}`.

## Tasks / Subtasks

- [ ] Add or update admin API auth pipeline (no duplicate auth plug)
  - [ ] Define an `/api/admin/v1` scope that pipes through a single admin REST auth plug (extend existing `fetch_current_scope_for_api_user/2` if possible)
  - [ ] Ensure the admin auth plug assigns `current_scope` from a valid Bearer token
  - [ ] Ensure unauthorized responses use the REST error envelope and status 401
- [ ] Align token validation with existing Accounts token helpers
  - [ ] Use `Accounts.fetch_user_by_api_token/1` for Bearer tokens
  - [ ] Keep token expiry behavior (1 day) as defined in `UserToken.verify_api_token_query/1`
- [ ] Tests
  - [ ] Unauthorized admin request returns 401 with REST error envelope
  - [ ] Invalid/malformed token returns 401 with REST error envelope
  - [ ] Valid token allows the request to proceed and assigns `current_scope.user`
- [ ] Add admin login API to retrieve a Bearer token
  - [ ] Create `POST /api/admin/v1/login` accepting email + password
  - [ ] Return a Bearer token using the REST error envelope on failure
  - [ ] Tests: success returns token, invalid credentials returns 401, invalid params returns 422

## Dev Notes

- Current API auth lives in `TaurosWeb.UserAuth.fetch_current_scope_for_api_user/2` and parses `Authorization: Bearer <token>`.
- The current failure response is plain text; update admin auth to return a JSON REST error envelope: `{error: %{code, message, details}}`.
- Admin endpoints are intended for `/api/admin/v1/*` and use Bearer tokens tied to users. Use `Accounts.fetch_user_by_api_token/1` and `Scope.for_user/1` to set `current_scope`.
- Keep admin auth in the router pipeline (no controller-level auth) to satisfy the "router-level auth" rule.
- Do not add a second auth plug for admin; extend the existing API auth flow so the logic stays centralized.
- Ensure error handling is consistent with the REST envelope requirement from the PRD/Architecture.
- REST error envelope example (401): `{"error":{"code":"unauthorized","message":"Invalid or missing bearer token","details":{}}}`.

### Auth Requirements (REST Admin)

- Scope: `/api/admin/v1/*` only.
- Scheme: `Authorization: Bearer <token>` (case-insensitive `Bearer` prefix).
- Failure: respond with status 401 and `{error: %{code, message, details}}`.
- Success: assign `current_scope` with `current_scope.user` present.
 - Login response: `{data: %{token: "Bearer <token>"}}`.

### Suggested Implementation Sequence

1. Update router to introduce `/api/admin/v1` scope with the admin auth plug.
2. Extend `fetch_current_scope_for_api_user/2` to return JSON error envelope on failures.
3. Add controller tests to assert 401 and envelope shape; add a success-path test that verifies `current_scope.user`.

### Project Structure Notes

- Router: `lib/tauros_web/router.ex` (admin API scope and pipeline)
- Auth plug: `lib/tauros_web/user_auth.ex`
- Accounts API token helpers: `lib/tauros/accounts.ex`, `lib/tauros/accounts/user_token.ex`
- Admin controllers: `lib/tauros_web/controllers/api/admin/`
- Tests: `test/tauros_web/controllers/api/admin/` or `test/tauros_web/`

### References

- `_bmad-output/planning-artifacts/epics.md#Story 1.1`
- `_bmad-output/planning-artifacts/prd.md#API Backend Specific Requirements`
- `_bmad-output/planning-artifacts/architecture.md#Authentication & Security`
- `_bmad-output/project-context.md#Critical Implementation Rules`

## Dev Agent Record

### Agent Model Used

GPT-5 (Codex CLI)

### Debug Log References

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.

### File List

- `_bmad-output/implementation-artifacts/1-1-admin-authentication-for-admin-endpoints.md`
