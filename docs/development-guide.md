# Development Guide

## Prerequisites
- Elixir ~> 1.15 and Erlang/OTP
- PostgreSQL (for Ecto)

## Setup
```bash
mix setup
```

## Run Locally
```bash
mix phx.server
```
Or:
```bash
iex -S mix phx.server
```

## Assets
```bash
mix assets.build
```
For production assets:
```bash
mix assets.deploy
```

## Tests
```bash
mix test
```

## Controller Patterns
Shared controller patterns live in `docs/controller-patterns.md`.

## Review Checklist
Use the review checklist in `docs/review-checklist.md` for generator alignment and controller consistency.

## Configuration
- Environment config files under `config/` (`dev.exs`, `test.exs`, `prod.exs`, `runtime.exs`).
- Secrets and runtime values typically provided via environment variables.
