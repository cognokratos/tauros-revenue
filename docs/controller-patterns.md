# Controller Patterns

## Purpose
Provide a single, shared reference for API controller behavior so agent, customer, and account flows stay consistent.

## Core Rules
- Controllers call contexts for all data writes and reads.
- Use `action_fallback` with the correct fallback controller.
- Use JSON view modules for success responses and error envelopes.
- Do not access `Repo` directly from controllers.
- Preserve standard REST error envelope: `{error: %{code, message, details}}`.

## Admin Create Controller Pattern (Bearer)
Use this pattern in admin create controllers such as agents and customers.

1. Ensure the route is under the admin pipeline and versioned scope.
2. Accept params as the generated controller does: `def create(conn, %{"record" => params}) do`.
3. Call the context create function with `current_scope` first.
4. On success, render JSON via the matching `*JSON` module.
5. On error, return via fallback controller.

Example (shape only):
```elixir
plug :action_fallback, TaurosWeb.Api.Admin.FallbackController

def create(conn, %{"record" => params}) do
  with {:ok, record} <- Context.create_record(conn.assigns.current_scope, params) do
    render(conn, :show, record: record)
  end
end
```

## Agent Create Controller Pattern (X-API-KEY)
Use this pattern in agent-scoped endpoints such as accounts.

1. Ensure the route is under `:api_agent` with `X-API-KEY` auth.
2. Accept params as the generated controller does: `def create(conn, %{"record" => params}) do`.
3. Call the context create function with `current_agent` first.
4. On success, render JSON via the matching `*JSON` module.
5. On error, return via agent fallback controller.

Example (shape only):
```elixir
plug :action_fallback, TaurosWeb.Api.Agent.FallbackController

def create(conn, %{"record" => params}) do
  with {:ok, record} <- Context.create_record(conn.assigns.current_agent, params) do
    render(conn, :show, record: record)
  end
end
```

## Alignment Checklist for Create Actions
- `create/2` signature matches generator output (`conn, %{"record" => params}`).
- Uses `action_fallback` and `render/3` with JSON views.
- Context function accepts scoped entity first (`current_scope` or `current_agent`).
- Errors are surfaced via fallback with standard envelope.
- No direct `Repo` access or custom response formatting.
