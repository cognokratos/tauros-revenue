# Architecture

## Executive Summary
Tauros is a Phoenix (Elixir) web application using LiveView for server-rendered UI and Ecto for data access. The codebase is a single Phoenix app with domain logic under `lib/tauros/` and web layer under `lib/tauros_web/`.

## Technology Stack
- Language: Elixir (~> 1.15)
- Web framework: Phoenix (~> 1.8.3) with LiveView (~> 1.1.0)
- Data layer: Ecto + Postgrex
- Web server: Bandit
- Frontend tooling: Tailwind + esbuild
- Email: Swoosh
- HTTP client: Req

## Architecture Pattern
- Phoenix MVC with LiveView for interactive UI
- Context-driven domain organization under `lib/tauros/`
- Web interface under `lib/tauros_web/` (router/controllers/live/components)

## Data Architecture
- Ecto schemas and contexts under `lib/tauros/`
- Migrations under `priv/repo/migrations/`
- Database: PostgreSQL (via `postgrex`)

## API Design
- Routing defined in `lib/tauros_web/router.ex`
- HTTP controllers under `lib/tauros_web/controllers/`
- LiveViews under `lib/tauros_web/live/`
- Quick scan only; a deep scan is needed for endpoint-level details

## Component Overview
- Core UI components: `lib/tauros_web/components/core_components.ex`
- Layouts: `lib/tauros_web/components/layouts.*`
- LiveView UI modules: `lib/tauros_web/live/`

## Source Tree
See `docs/source-tree-analysis.md` for annotated structure.

## Development Workflow
- Setup: `mix setup`
- Run: `mix phx.server` or `iex -S mix phx.server`
- Assets: `mix assets.build` (dev), `mix assets.deploy` (prod)

## Deployment Architecture
- Standard Phoenix release flow; no explicit CI/CD or Docker config detected
- Static assets compiled into `priv/static/assets/`

## Testing Strategy
- ExUnit tests under `test/`
- Mix alias: `mix test` (with `ecto.create` and `ecto.migrate`)
