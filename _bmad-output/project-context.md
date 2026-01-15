---
project_name: 'tauros-revenue'
user_name: 'Victor'
date: '2026-01-15T22:49:56+0100'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'style_rules', 'workflow_rules', 'dont_miss_rules']
status: 'complete'
rule_count: 32
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- Elixir `~> 1.15`
- Phoenix `~> 1.8.3`
- Phoenix LiveView `~> 1.1.0`
- Ecto `~> 3.13`
- PostgreSQL + pgvector
- Tailwind `~> 0.3`
- esbuild `~> 0.10`
- Bandit `~> 1.5`
- Req `~> 0.5`
- Arcana `~> 1.2.0`
- Anubis MCP `~> 0.17.0`

## Critical Implementation Rules

### Language-Specific Rules (Elixir)

- Use `Enum.at/2` or pattern matching for list index access; never use `list[i]`
- Do not rebind inside `if/case/cond`; bind the result outside the block
- Do not use map access on structs; use `struct.field` or `Ecto.Changeset.get_field/2`
- Avoid `String.to_atom/1` on user input
- Predicate functions end with `?` and do not start with `is_`
- Use `Task.async_stream/3` for concurrent enumeration when needed
- Use `Req` for HTTP calls

### Framework-Specific Rules (Phoenix/LiveView)

- LiveView templates start with `<Layouts.app flash={@flash} ...>` and pass `current_scope`
- Use `<.input>` for form inputs; do not access changesets directly in templates
- Use `<.form for={@form}>` with `to_form/2`; never use `form_for`
- Use `<.link navigate>`/`push_navigate`; avoid `live_redirect`/`live_patch`
- Stream lists with `stream/3`, `phx-update="stream"`, and `@streams.*`

### Testing Rules

- Use `start_supervised!/1` for processes in tests
- Avoid `Process.sleep/1`; use `Process.monitor/1` and assert on `:DOWN`
- Use `Phoenix.LiveViewTest` helpers with `LazyHTML`; avoid raw HTML asserts
- Prefer key element IDs and selectors over text content in assertions

### Code Quality & Style Rules

- Use snake_case for files, functions, and JSON fields
- Keep contexts split by domain: `Agents`, `Customers`, `Wallets`, `Billing`, `Audit`, `Rag`
- Use `<.input>` and `<.form>` patterns consistently in templates
- Use Tailwind classes; do not use `@apply` in CSS
- Do not use inline `<script>` in HEEx; use colocated hooks

### Development Workflow Rules

- Run `mix precommit` after completing changes
- Generate migrations with `mix ecto.gen.migration name_using_underscores`
- Place routes in correct `live_session` scopes and pass `current_scope`

### Critical Don't-Miss Rules

- Always enforce `agent_id` scoping at DB level and in context queries
- Never access `@current_user`; use `@current_scope.user`
- Never use `<.flash_group>` outside `layouts.ex`
- REST errors use `{error: %{code, message, details}}`; MCP errors are structured text
- Audit logs are immutable; no updates or deletes
- Embeddings live in `invoice_embeddings`; update on invoice create/update

---

## Usage Guidelines

**For AI Agents:**
- Read this file before implementing any code
- Follow all rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**
- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-01-15
