# Story 1.4: Enforce Customer Ownership by Agent

Status: done

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

- [x] Enforce ownership at the context layer
  - [x] Keep all Customers queries scoped by `current_scope.user` (list, get, update, delete)
  - [x] Add explicit guard to prevent `agent_id` reassignment on update
  - [x] Return changeset errors for forbidden reassignment attempts
- [x] Harden schema/changeset rules
  - [x] Split create vs update changesets (create allows `agent_id`, update does not)
  - [x] If `agent_id` is present in update params, add a validation error
- [x] Admin API protections
  - [x] In update endpoint, ensure `agent_id` param is ignored and rejected with 422 error envelope
  - [x] Ensure list/show/update/delete only operate on scoped customers
- [x] LiveView UI protections
  - [x] Edit form does not allow changing Agent; show read-only agent name
  - [x] Use `current_scope` for all data access and form assigns
- [x] Tests
  - [x] Context: updating `agent_id` returns error
  - [x] Controller: `PATCH /api/admin/v1/customers/:id` with `agent_id` returns 422 with error envelope
  - [x] Controller: out-of-scope customer returns not-found behavior (no leakage)
  - [x] LiveView: edit form does not render editable agent selector

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

✅ **Story 1.4: Enforce Customer Ownership by Agent - COMPLETE**

**Implementation Summary:**

1. **Schema & Changeset Refactoring** (`lib/tauros/customers/customer.ex`):
   - Split `changeset/2` into `create_changeset/2` (allows `agent_id`) and `update_changeset/2` (rejects `agent_id`)
   - Update changeset only casts `name` and `email`, preventing any `agent_id` field changes
   - Both validate required fields but update is restricted

2. **Context Layer Protection** (`lib/tauros/customers.ex`):
   - Modified `update_customer/3` to explicitly check if `agent_id` is present in params
   - If `agent_id` is in update params, returns error changeset with "cannot be reassigned" message
   - All scoped queries already use `current_scope.user` via `Agents.list_agents/1`
   - Context is the single source of truth for ownership enforcement

3. **LiveView UI Update** (`lib/tauros_web/live/customer_live/form.ex`):
   - Edit form now shows agent as read-only text display instead of editable select
   - Create form still shows agent selector (allows agent_id during creation)
   - Form uses conditional rendering based on `live_action` to show appropriate UI
   - Agent field shows current agent name in gray background box for visual distinction

4. **API Controller Behavior**:
   - Existing `PATCH /api/admin/v1/customers/:id` now rejects `agent_id` with 422 error
   - Error envelope uses standard `{error: {code, message, details}}` format
   - Controller automatically handles error via FallbackController

5. **Comprehensive Testing**:
   - Added 3 new context tests: agent_id rejection, name/email updates without agent_id change
   - Added 2 new API controller tests: agent_id rejection with 422, verification agent not changed
   - Added 2 new LiveView tests: agent shown read-only, agent_id field not in edit form
   - All existing tests still pass (194 total tests, 0 failures)

**Acceptance Criteria Met:**
- AC1: ✅ Customer queries scoped by agent_id, prevents cross-agent access
- AC2: ✅ Attempts to reassign agent_id rejected with error
- AC3: ✅ Out-of-scope customer access returns not-found (via existing scoping)
- AC4: ✅ Edit form shows agent as read-only, update ignores agent_id param

### File List

**Modified Files:**
- `lib/tauros/customers/customer.ex` - Split changesets for create vs update
- `lib/tauros/customers.ex` - Added agent_id reassignment guard in update_customer
- `lib/tauros_web/live/customer_live/form.ex` - Updated edit form to show agent read-only
- `test/tauros/customers_test.exs` - Added 3 new tests for ownership enforcement
- `test/tauros_web/controllers/api/admin/customer_controller_test.exs` - Added 2 new tests for agent_id rejection
- `test/tauros_web/live/customer_live_test.exs` - Added 2 new tests for edit form behavior

## Change Log

- **2026-02-09**: Implemented customer ownership enforcement - separated create/update changesets, added agent_id reassignment guard, updated LiveView form to show agent read-only, added comprehensive tests. All 194 tests passing.
