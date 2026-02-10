# Review Checklist

## Goal
Prevent drift between similar controller flows and keep generator-aligned behavior consistent.

## Generator-Alignment Step (Required)
- [ ] Compare the controller against the generator default structure.
- [ ] Confirm `create/2` signature matches (`conn, params`).
- [ ] Confirm `action_fallback` is used.
- [ ] Confirm JSON response is rendered through `*JSON` module.
- [ ] Confirm errors use the standard envelope `{error: %{code, message, details}}`.

## API Controller Consistency
- [ ] Response shape matches equivalent controller (agent, customer, account).
- [ ] Context functions receive scoped entity first (`current_scope` or `current_agent`).
- [ ] No direct `Repo` access from controller.
- [ ] Auth pipeline used (`:api_admin` or `:api_agent`).

## UI and LiveView Consistency
- [ ] LiveViews use `<Layouts.app flash={@flash} current_scope={@current_scope}>`.
- [ ] Streams use `phx-update="stream"` and DOM IDs per item.
- [ ] Links use `<.link navigate>` or `push_navigate`.
