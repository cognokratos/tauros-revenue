# Project Overview

## Project Name
Tauros

## Purpose
Phoenix web application scaffold with authentication and LiveView UI.

## Executive Summary
Tauros is a single Phoenix application using LiveView and Ecto. The web layer lives under `lib/tauros_web/`, while business logic and contexts live under `lib/tauros/`. The project uses Tailwind and esbuild for assets and PostgreSQL for persistence.

## Technology Stack (Summary)
| Category | Technology | Version | Notes |
| --- | --- | --- | --- |
| Language | Elixir | ~> 1.15 | `mix.exs` |
| Web Framework | Phoenix | ~> 1.8.3 | LiveView enabled |
| Live UI | Phoenix LiveView | ~> 1.1.0 | Server-rendered UI |
| Data | Ecto + Postgrex | ~> 3.13 | PostgreSQL adapter |
| Assets | Tailwind + esbuild | ~> 0.3 / 0.10 | Mix tasks |
| Server | Bandit | ~> 1.5 | HTTP server |

## Architecture Type
Phoenix MVC with LiveView.

## Repository Structure
Single-part (monolith) Phoenix application.

## Detailed Documentation
- [Architecture](./architecture.md)
- [Source Tree Analysis](./source-tree-analysis.md)
- [Component Inventory](./component-inventory.md)
- [Development Guide](./development-guide.md)
- [API Contracts](./api-contracts-web.md)
- [Data Models](./data-models-web.md)
