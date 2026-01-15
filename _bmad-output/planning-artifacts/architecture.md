---
stepsCompleted:
  - 1
  - 2
  - 3
  - 4
  - 5
  - 6
  - 7
inputDocuments:
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/product-brief.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/prd.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/project-context-user.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/index.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/project-overview.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/architecture.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/development-guide.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/source-tree-analysis.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/component-inventory.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/api-contracts-web.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/data-models-web.md
workflowType: 'architecture'
project_name: 'tauros-revenue'
user_name: 'Victor'
date: '2026-01-15T22:03:16+0100'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
The system must support three coordinated interfaces: LiveView UI for humans, REST APIs for services, and MCP tools for agents. Core flows include: admin registration of agents/customers, agent/service creation of accounts, agent-driven invoice creation with human approval, status updates via API, RAG-based invoice queries, and audit log visibility. Architecturally, this implies consistent domain rules across web, API, and MCP surfaces; a shared invoice workflow; and a clear separation of admin vs agent/service permissions.

**Non-Functional Requirements:**
- Performance: p95 < 500ms for REST/MCP
- Reliability: 99.99% uptime and zero data loss
- Security: TLS in transit, encryption at rest, strict auth separation
- Compliance: audit trail (who/what/when), GDPR-aligned export/purge
These NFRs will drive data model design, audit/event capture, and access-control layering.

**Scale & Complexity:**
- Primary domain: web app + API backend + agent interface
- Complexity level: high
- Estimated architectural components: 6-9 (auth, agents/customers, accounts, invoices, audit/logging, MCP/RAG, API surface, LiveView UI, encryption/compliance support)

### Technical Constraints & Dependencies

- Phoenix 1.8 + LiveView 1.1 with Ecto/Postgres
- Req as HTTP client
- pgvector for RAG with Arcana and an Ollama-based embedder
- Anubis MCP server for agent tools
- No private key handling; public addresses only
- Docker release generation via `mix phx.gen.release --docker`

### Cross-Cutting Concerns Identified

- Consistent authorization rules across UI, REST, and MCP
- Audit logging for all lifecycle changes
- Human approval gate for AI-generated invoices
- Data encryption at rest for sensitive fields
- Versioned APIs and tool contracts

## Starter Template Evaluation

### Primary Technology Domain

Phoenix web app + API backend + MCP agent interface, based on project requirements analysis.

### Starter Options Considered

- **Phoenix official generator (`mix phx.new`)**: selected and already in use; aligns with the LiveView-first UI, Ecto/Postgres data layer, and Phoenix routing/controller patterns required by the PRD.
- **Alternatives**: none considered, since the project is already initialized and the PRD explicitly calls for Phoenix/LiveView.

### Selected Starter: Phoenix (`mix phx.new`)

**Rationale for Selection:**
- Matches existing codebase and PRD requirements.
- Provides LiveView, MVC structure, and Ecto out of the box.
- Supports binary UUIDs as required for schemas.
- Consistent with local Docker deployment for Postgres + pgvector.

**Initialization Command:**

```bash
mix phx.new tauros-revenue --binary-id --app tauros --module Tauros
mix phx.gen.auth Accounts User users
```

**Architectural Decisions Provided by Starter:**

**Language & Runtime:**
- Elixir `~> 1.15` (from `mix.exs`)
- Phoenix `~> 1.8.3`, LiveView `~> 1.1.0`

**Styling Solution:**
- Tailwind `~> 0.3` + Phoenix core components

**Build Tooling:**
- esbuild `~> 0.10`
- Phoenix asset pipeline with `mix assets.*` aliases

**Testing Framework:**
- ExUnit with standard Phoenix test setup

**Code Organization:**
- Phoenix MVC + LiveView
- Domain contexts under `lib/tauros/`, web under `lib/tauros_web/`

**Development Experience:**
- Live reload (`phoenix_live_reload`)
- Bandit server (`~> 1.5`)
- Standard Phoenix mix aliases for setup/build/test

**Note:** Version verification is based on repository `mix.exs` due to no web access in this environment.

**Additional Dependencies (from project context):**
- `:anubis_mcp, "~> 0.17.0"`
- `:arcana, "~> 1.2.0"` (with custom Ollama embedder)
- Postgres + pgvector via Docker (`pgvector/pgvector:pg18-trixie`)

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Data model scoping enforced at DB level via `agent_id` foreign keys and constraints
- Separate `invoice_audit_logs` table for immutable audit trail
- Separate `invoice_embeddings` table for pgvector/RAG
- Admin auth: Bearer token tied to user session
- Agent auth: single API key per agent, hashed in DB
- REST error envelope standardized
- MCP error responses as structured text
- Docker Compose for app + pgvector

**Important Decisions (Shape Architecture):**
- Encryption at rest for API keys and PII only
- Authorization enforced in contexts (no policy layer)
- OpenAPI spec + markdown examples for API docs
- LiveView UI split into separate domain LiveViews
- Inline approve/reject in invoice list; audit as separate tab
- `.env` + `runtime.exs` for config
- Basic Logger to stdout
- Basic GitHub Actions for tests

**Deferred Decisions (Post-MVP):**
- Rate limiting

### Data Architecture

- **Audit Logs:** separate `invoice_audit_logs` table for immutable history
- **RAG Storage:** separate `invoice_embeddings` table (pgvector)
- **Multi-tenancy:** enforce `agent_id` scoping at DB level (FKs + indexes/constraints)
- **Validation:** Ecto changeset-centric validation; constraints mirrored in DB

### Authentication & Security

- **Admin Auth:** Bearer token tied to user session (Phoenix auth)
- **Agent Auth:** single API key per agent; hash at rest
- **Encryption at Rest:** API keys + PII only
- **Authorization:** enforced in contexts

### API & Communication Patterns

- **REST Versioning:** `/api/v1`, `/api/admin/v1`
- **MCP Versioning:** `/mcp/v1`
- **REST Error Envelope:** `{error: %{code, message, details}}`
- **MCP Errors:** structured text with `code` and `message`
- **API Docs:** OpenAPI spec + markdown examples
- **Rate Limiting:** deferred post-MVP
- **Shared Core:** contexts are source of truth across UI/REST/MCP

### Frontend Architecture

- **Structure:** separate LiveViews per domain (Agents, Customers, Accounts, Invoices)
- **Components:** function components only; avoid LiveComponents
- **Approval Workflow:** inline approve/reject on invoice list
- **Audit Visibility:** separate audit tab

### Infrastructure & Deployment

- **Docker:** `docker-compose` for app + pgvector
- **Release:** Phoenix release via `mix phx.gen.release --docker`
- **Config:** `.env` + `runtime.exs`
- **Logging:** Logger to stdout
- **CI/CD:** basic GitHub Actions for tests

### Decision Impact Analysis

**Implementation Sequence:**
1. Data models + migrations (agents/customers/accounts/invoices/audit/embeddings)
2. Auth & authorization scaffolding (admin bearer + agent keys)
3. Core contexts and business rules (approval workflow, audit logging)
4. API surface (REST + MCP) using shared contexts
5. LiveView UI per domain with approval flows
6. RAG integration and embeddings pipeline
7. OpenAPI spec + documentation
8. Docker compose + release config + CI

**Cross-Component Dependencies:**
- Auth/authorization decisions shape all queries and UI visibility
- Audit logging impacts invoice lifecycle changes across UI, REST, MCP
- RAG storage depends on invoice persistence and audit visibility
- Docker/compose influences local development and release pipelines

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:**
Naming, structure, API formats, communication, and process patterns across LiveView, REST, and MCP.

### Naming Patterns

**Database Naming Conventions:**
- Tables: plural snake_case (e.g., `invoice_audit_logs`, `invoice_embeddings`)
- Columns: snake_case (e.g., `agent_id`, `created_at`)
- Foreign keys: `{table}_id` (e.g., `agent_id`)
- Indexes: `index_{table}_{column}` (Ecto default)

**API Naming Conventions:**
- REST endpoints: plural (e.g., `/api/v1/invoices`)
- Route params: `:id`
- Query params: snake_case (e.g., `customer_id`)
- Headers: `X-API-KEY`, `Authorization: Bearer ...`

**Code Naming Conventions:**
- Modules: `Tauros.Billing.Invoice`
- Functions: snake_case (Elixir standard)
- Files: snake_case (e.g., `invoice.ex`, `invoice_controller.ex`)

### Structure Patterns

**Project Organization:**
- Contexts separated by domain: `Accounts`, `Billing`, `Audit`, `Rag`
- LiveViews per domain under `lib/tauros_web/live/{domain}_live/`
- Controllers for REST/MCP under `lib/tauros_web/controllers/`

**File Structure Patterns:**
- Tests in `test/` mirroring `lib/`
- OpenAPI spec under `docs/` (or `priv/` if needed for runtime)
- Docker and compose at project root

### Format Patterns

**API Response Formats:**
- Success responses: direct data payloads
- Error responses: `{error: %{code, message, details}}`

**Data Exchange Formats:**
- JSON fields: snake_case
- Dates/times: ISO 8601 strings
- Booleans: true/false

### Communication Patterns

**Event System Patterns:**
- Audit events written via context functions only
- No ad-hoc event formats in controllers/LiveViews

### Process Patterns

**Error Handling Patterns:**
- REST errors use standardized envelope
- MCP errors return structured text with `code` and `message`
- User-facing errors surfaced via LiveView flashes

**Loading State Patterns:**
- Use `:loading` assigns in LiveViews
- Disable primary actions during async operations

### Enforcement Guidelines

**All AI Agents MUST:**

- Use context functions for all data writes (no direct schema writes from controllers/LiveViews)
- Apply `agent_id` scoping at query boundaries
- Use standardized REST/MCP error formats

**Pattern Enforcement:**
- Code review checklist verifies naming/format conventions
- Deviations documented in `docs/architecture.md` updates
- Patterns updated only via this architecture document

### Pattern Examples

**Good Examples:**
- `Billing.create_invoice/2` invoked by REST + MCP + LiveView
- `GET /api/v1/invoices?customer_id=...`
- JSON: `{ "invoice_id": "...", "payment_status": "pending" }`

**Anti-Patterns:**
- Controllers inserting directly into repos
- Mixed camelCase JSON fields
- Ad-hoc audit formats in LiveViews

## Project Structure & Boundaries

### Complete Project Directory Structure
```
tauros-revenue/
├── README.md
├── mix.exs
├── mix.lock
├── .env
├── .env.example
├── docker-compose.yml
├── Dockerfile
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   ├── runtime.exs
│   └── test.exs
├── docs/
│   ├── index.md
│   ├── openapi.yaml
│   ├── project-overview.md
│   ├── architecture.md
│   ├── development-guide.md
│   ├── source-tree-analysis.md
│   ├── component-inventory.md
│   ├── api-contracts-web.md
│   └── data-models-web.md
├── assets/
│   ├── css/
│   └── js/
├── lib/
│   ├── tauros/
│   │   ├── accounts/                 # Phoenix auth context (existing)
│   │   ├── agents/                   # Agent registration + API keys
│   │   ├── customers/                # Customer management
│   │   ├── wallets/                  # Blockchain account management
│   │   ├── billing/                  # Invoices + approval workflow
│   │   ├── audit/                    # Invoice audit logs
│   │   ├── rag/                      # Embeddings + query interface
│   │   ├── repos/                    # optional repo helpers
│   │   └── tauros.ex
│   ├── tauros_web/
│   │   ├── components/
│   │   ├── controllers/
│   │   │   ├── api/
│   │   │   │   ├── admin/            # Admin REST endpoints
│   │   │   │   └── public/           # Agent/service REST endpoints
│   │   │   └── error_*.ex
│   │   ├── live/
│   │   │   ├── agents_live/
│   │   │   ├── customers_live/
│   │   │   ├── wallets_live/
│   │   │   ├── invoices_live/
│   │   │   └── audit_live/
│   │   ├── mcp_server/               # TaurosWeb.MCPServer + tools
│   │   ├── router.ex
│   │   └── endpoint.ex
│   └── tauros_web.ex
├── priv/
│   ├── repo/
│   │   └── migrations/
│   └── static/
└── test/
    ├── tauros/
    └── tauros_web/
```

### Architectural Boundaries

**API Boundaries:**
- Admin REST: `/api/admin/v1/*` → `TaurosWeb.Controllers.Api.Admin.*`
- Public REST: `/api/v1/*` → `TaurosWeb.Controllers.Api.Public.*`
- MCP: `/mcp/v1` → `TaurosWeb.MCPServer`

**Component Boundaries:**
- LiveView UI per domain under `lib/tauros_web/live/*`
- Shared UI components in `lib/tauros_web/components`

**Service Boundaries:**
- Contexts are the source of truth; controllers and LiveViews call contexts only

**Data Boundaries:**
- Ecto schemas per context
- `invoice_audit_logs` and `invoice_embeddings` isolated to `Audit` and `Rag`

### Requirements to Structure Mapping

**Feature Mapping:**
- Agents → `lib/tauros/agents`, `lib/tauros_web/live/agents_live`, admin REST
- Customers → `lib/tauros/customers`, `lib/tauros_web/live/customers_live`, admin REST
- Wallet Accounts → `lib/tauros/wallets`, `lib/tauros_web/live/wallets_live`, public REST
- Invoices + Approval → `lib/tauros/billing`, `lib/tauros_web/live/invoices_live`, MCP tools
- Audit Logs → `lib/tauros/audit`, `lib/tauros_web/live/audit_live`
- RAG Queries → `lib/tauros/rag`, `TaurosWeb.MCPServer`
- Auth → `lib/tauros/accounts` + existing LiveViews

**Cross-Cutting Concerns:**
- Authorization enforced in context queries
- Audit logging invoked from context-level workflow functions
- API error envelope and MCP error format enforced in controllers/MCPServer

### Integration Points

**Internal Communication:**
- All interface layers call contexts
- RAG embeddings triggered from Billing/Audit contexts

**External Integrations:**
- Ollama embedding API via Arcana (Rag context)
- MCP protocol via Anubis MCP (Web layer)

**Data Flow:**
- Agent creates invoice → Billing context → Audit log + Embedding
- Human approval in LiveView → Billing context → Audit log
- RAG query via MCP → Rag context → returns summarized results

### File Organization Patterns

**Configuration Files:**
- `.env` for local overrides
- `runtime.exs` for runtime configuration

**Source Organization:**
- Contexts under `lib/tauros/*`
- Web under `lib/tauros_web/*`

**Test Organization:**
- `test/` mirrors `lib/`

**Asset Organization:**
- `assets/` for JS/CSS
- `priv/static/` for compiled assets

### Development Workflow Integration

**Development Server Structure:**
- Phoenix LiveView with domain LiveViews and REST controllers

**Build Process Structure:**
- `mix assets.*` for frontend, `mix compile` for backend

**Deployment Structure:**
- Docker Compose for app + pgvector
- Phoenix release via `mix phx.gen.release --docker`

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
All choices are compatible: Phoenix/LiveView + REST + MCP share contexts, pgvector + Arcana fits RAG needs, and Docker Compose supports local deployment.

**Pattern Consistency:**
Naming, structure, and API formats align with Phoenix conventions and the chosen stack.

**Structure Alignment:**
The project structure cleanly maps contexts and web interfaces, with MCP isolated in `TaurosWeb.MCPServer`.

### Requirements Coverage Validation ✅

**Epic/Feature Coverage:**
No epics provided; FR categories are fully mapped to contexts and web interfaces.

**Functional Requirements Coverage:**
- Agents/customers/accounts/invoices/approval/audit/RAG all have assigned contexts and endpoints.
- REST and MCP surfaces are explicitly versioned and structured.

**Non-Functional Requirements Coverage:**
- Performance target supported by Phoenix + Ecto, with room for optimization.
- Security via bearer + API key auth, hashed storage, encryption for PII.
- Compliance covered via audit logs + GDPR export/purge patterns.

### Implementation Readiness Validation ✅

**Decision Completeness:**
Critical decisions captured with stack versions from repository.

**Structure Completeness:**
Directory structure and boundaries are fully specified.

**Pattern Completeness:**
Naming, formatting, and process patterns are defined with examples.

### Gap Analysis Results

**Critical Gaps:** None.

**Important Gaps:**
- Define audit log immutability enforcement (DB constraints vs application-only).
- Specify OpenAPI ownership and update process.
- Define RAG embedding update triggers (create/update invoice, or explicit job).

**Nice-to-Have Gaps:**
- Document rate limiting strategy for post-MVP.
- Add example error codes list for REST/MCP.

### Validation Issues Addressed

- Documented gaps to be resolved during implementation planning.

### Architecture Completeness Checklist

**✅ Requirements Analysis**

- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**✅ Architectural Decisions**

- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**✅ Implementation Patterns**

- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**✅ Project Structure**

- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** high

**Key Strengths:**
- Clear multi-surface architecture with shared contexts
- Explicit audit + approval workflow alignment
- Strong consistency rules for AI agents

**Areas for Future Enhancement:**
- Rate limiting and advanced monitoring
- Formalized error code taxonomy

### Implementation Handoff

**AI Agent Guidelines:**

- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries
- Refer to this document for all architectural questions

**First Implementation Priority:**
Define audit immutability, OpenAPI ownership, and RAG embedding triggers; then begin data model + migrations.
