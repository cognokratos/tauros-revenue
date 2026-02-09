# Story 1.4: Enforce Customer Ownership by Agent

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin user,
I want customers to be scoped to their owning Agent,
so that data access respects ownership boundaries.

## Acceptance Criteria

1. Given a Customer record, when it is queried or referenced in admin operations (UI or admin API), then the system enforces `agent_id` scoping at the query boundary and prevents access outside the owning Agent.
2. Given an attempt to associate a Customer with a different Agent (via update or edit), when the system validates the association, then it rejects the change and returns a standardized error response.
3. Given an admin user requests a Customer outside their ownership scope, when the request is processed, then the system responds with the same not-found behavior as other scoped resources (no cross-agent leakage).
4. Given an admin user edits a Customer, when the edit form renders, then the owning Agent is not editable (read-only or hidden) and the update ignores any `agent_id` param.

## Tasks / Subtasks

- [ ] Enforce ownership at the context layer
  - [ ] Keep all Customers queries scoped by `current_scope.user` (list, get, update, delete)
  - [ ] Add explicit guard to prevent `agent_id` reassignment on update
  - [ ] Return changeset errors for forbidden reassignment attempts
- [ ] Harden schema/changeset rules
  - [ ] Split create vs update changesets (create allows `agent_id`, update does not)
  - [ ] If `agent_id` is present in update params, add a validation error
- [ ] Admin API protections
  - [ ] In update endpoint, ensure `agent_id` param is ignored and rejected with 422 error envelope
  - [ ] Ensure list/show/update/delete only operate on scoped customers
- [ ] LiveView UI protections
  - [ ] Edit form does not allow changing Agent; show read-only agent name
  - [ ] Use `current_scope` for all data access and form assigns
- [ ] Tests
  - [ ] Context: updating `agent_id` returns error
  - [ ] Controller: `PATCH /api/admin/v1/customers/:id` with `agent_id` returns 422 with error envelope
  - [ ] Controller: out-of-scope customer returns not-found behavior (no leakage)
  - [ ] LiveView: edit form does not render editable agent selector

## Dev Notes

- Ownership enforcement must happen in the Customers context, not in controllers or LiveViews.
- Use `current_scope.user` for scoping (never `@current_user`).
- Avoid direct Repo writes in controllers/LiveViews; always call context functions.
- LiveView templates must start with `<Layouts.app flash={@flash} current_scope={@current_scope}>`.
- REST errors must use `{error: %{code, message, details}}`.
- If you touch UI layout or copy, follow the Quiet Ledger UX direction in `ux-design-specification.md`.

## Developer Context

This story tightens ownership rules across existing Customers CRUD flows. The admin API and LiveView already use `Customers.list_customers/1` and `Customers.get_customer!/2` for scoping, but update flows currently permit `agent_id` changes via the shared changeset. This must be locked down to prevent cross-agent reassignment and leakage.

Dependencies: Story 1.2 (Agents) and Story 1.3 (Customers) are complete. Use existing admin auth and error envelope patterns from those stories.

## Technical Requirements

- Context-level guardrails:
  - Update changeset must not accept `agent_id` (reject if present).
  - `Customers.update_customer/3` should return a changeset error for reassignment attempts.
- Admin API:
  - `PATCH /api/admin/v1/customers/:id` must reject `agent_id` changes with 422 and error envelope.
  - `GET/DELETE/PATCH` must only act on scoped customers (no cross-agent access).
- UI:
  - Edit form should not allow changing Agent ownership; show read-only agent name if needed.
  - Use streams and `current_scope` conventions from existing LiveViews.
  - Keep UI calm and scannable (Quiet Ledger pattern); avoid adding dense controls.

- Error envelope examples:
  - Forbidden reassignment (API, 422):
    ```json
    { "error": { "code": "invalid_agent_id", "message": "agent_id cannot be reassigned", "details": {} } }
    ```
  - Out-of-scope access (API, 404):
    ```json
    { "error": { "code": "not_found", "message": "customer not found", "details": {} } }
    ```

## Architecture Compliance

- Enforce `agent_id` scoping at query boundaries and keep contexts as the source of truth.
- Respect admin vs agent/service auth separation.
- Preserve REST error envelope and MCP error format standards.

## Library & Framework Requirements

- Phoenix 1.8 / LiveView 1.1 / Ecto 3.13 (do not introduce new deps).
- Use `Req` for HTTP if needed (not expected here).

## File Structure Requirements

- Context: `lib/tauros/customers.ex`
- Schema: `lib/tauros/customers/customer.ex`
- Controller: `lib/tauros_web/controllers/api/admin/customer_controller.ex`
- LiveView: `lib/tauros_web/live/customer_live/form.ex`
- Tests: `test/tauros/customers_test.exs`, `test/tauros_web/controllers/api/admin/customer_controller_test.exs`, `test/tauros_web/live/customer_live_test.exs`

## Testing Requirements

- Context tests must verify ownership enforcement and rejection of `agent_id` reassignment.
- Controller tests must assert 422 error envelope when `agent_id` is present in update params.
- Controller tests must verify out-of-scope access returns not-found behavior.
- LiveView tests must assert no editable agent selector on edit and that `current_scope` is passed.

## Previous Story Intelligence

- Story 1.3 established Customers CRUD with scoping based on `current_scope.user` and an Agent selector in the form. Reuse its list/get patterns and error envelope helpers.
- Story 1.2 established Agents context and admin auth; use existing admin pipeline and error rendering conventions.

## Git Intelligence Summary

Recent commits show Story 1.3 followed existing admin auth patterns and scoped queries. Keep file locations and controller conventions consistent with those commits.

## Latest Tech Information

- Phoenix 1.8.3 is the current stable patch in the 1.8 series; LiveView 1.1.x is current. The project pins Phoenix `~> 1.8.3` and LiveView `~> 1.1.0`; do not upgrade during this story unless explicitly requested.
- Ecto 3.13.5 is the latest patch in the 3.13 series. The project already targets `~> 3.13`; keep within this series.
- Elixir 1.15 is the project baseline; follow existing tooling and avoid upgrading for this story.

## Project Context Reference

Key rules to follow:
- Enforce `agent_id` scoping at DB level and in context queries.
- Never access `@current_user`; use `@current_scope.user`.
- REST errors must use `{error: %{code, message, details}}`.
- Do not use `<.flash_group>` outside `layouts.ex`.
- Use `<.form for={@form}>` and `<.input>` with `to_form/2`.

## Story Completion Status

Status: ready-for-dev
Completion note: Ultimate context engine analysis completed - comprehensive developer guide created.

### Completion Verification Checklist

- [ ] Context rejects `agent_id` reassignment on update
- [ ] Admin API update returns 422 with error envelope when `agent_id` is provided
- [ ] Scoped access prevents cross-agent customer retrieval
- [ ] LiveView edit form does not allow agent reassignment
- [ ] No regressions in admin auth or Customers CRUD

## References

- `_bmad-output/planning-artifacts/epics.md#Story 1.4`
- `_bmad-output/planning-artifacts/prd.md#User & Identity Management`
- `_bmad-output/planning-artifacts/architecture.md#Authentication & Security`
- `_bmad-output/planning-artifacts/architecture.md#Data Architecture`
- `_bmad-output/implementation-artifacts/1-3-admin-registers-customer.md#Developer Context`
- `_bmad-output/project-context.md#Critical Don't-Miss Rules`
- `lib/tauros/customers.ex`
- `lib/tauros/customers/customer.ex`
- `lib/tauros_web/controllers/api/admin/customer_controller.ex`
- `lib/tauros_web/live/customer_live/form.ex`

## Dev Agent Record

### Agent Model Used

Codex (GPT-5)

### Debug Log References

None.

### Completion Notes List

✅ **Story 1.4: Enforce Customer Ownership by Agent - READY FOR DEV**

### File List

**New Files:**
- _bmad-output/implementation-artifacts/1-4-enforce-customer-ownership-by-agent.md
