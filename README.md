# Ταύρος Revenue

**Agentic financial workflow engineering with Elixir and Ash.**

Tauros is an open-source, educational revenue application covering customers,
wallet destinations, and later invoices, approvals, payments and
reconciliation. AI agents do the operational work. Humans keep the authority.

> How can AI safely take part in financial workflows without the model being
> given financial authority?

Tauros answers with architecture rather than prompts. Every interface (the
LiveView UI, the REST API and, next, AI tools through AshAI) calls the **same
Ash actions**. The same **policies** and **state machines** decide what may
happen, whoever is asking. An agent with a valid API key can read, draft and
propose; it can't approve, issue, mark paid or change who owns what.

| I want to… | Read |
| --- | --- |
| Understand why Tauros exists | [Vision](docs/VISION.md) · [AI capability is not authority](docs/AI-AUTHORITY.md) |
| See how it is built | [Architecture](docs/ARCHITECTURE.md) · [Domain model](docs/DOMAIN_MODEL.md) |
| Call the API | [REST API](docs/API.md) |
| Learn the concepts | [Learning path](docs/LEARNING-PATH.md) · [concepts/](docs/concepts) |
| Know what's next | [Roadmap](docs/ROADMAP.md) · [Workflows](docs/WORKFLOWS.md) |
| Contribute | [Development](docs/DEVELOPMENT.md) · [Security](docs/SECURITY.md) |

## Where it fits in CognoKratos

[CognoKratos](https://github.com/cognokratos) projects teach complementary
layers of agentic systems:

| Project | Teaches |
| --- | --- |
| [simple-agent-template](https://github.com/cognokratos/simple-agent-template) | production agent engineering: trust boundaries, MCP, guardrails, evaluation |
| [etf-research-agent](https://github.com/cognokratos/etf-research-agent) | governed decision engineering: policy-as-data, evidence, decision authority |
| [sophos-agent](https://github.com/cognokratos/sophos-agent) | agent construction: loops, memory, durable and local-first orchestration |
| [arktos-wallet](https://github.com/cognokratos/arktos-wallet) | secure financial and cryptographic capabilities: custody, keys, signing |
| **tauros-revenue** | **agentic financial workflows**: domain modelling, policies, human authority, state machines, idempotency, audit, reconciliation |

The Rust projects show how low-level infrastructure and protocols work.
Tauros shows how **Elixir and Ash compose sophisticated business and agentic
applications with very little handwritten infrastructure**.

**Tauros knows financial intent; Arktos knows cryptographic authority.** Tauros
stores public addresses only, and never holds or uses a key.

## Why Elixir and Ash

Ash describes the business as **declarations**: resources, actions, policies,
validations, changes and calculations. The framework enforces them identically
for every caller. The same declarations generate the JSON:API and its OpenAPI
spec, the LiveView forms, the database migrations and, with AshAI, the agent
tools. Ash extensions map one-to-one onto what Tauros teaches: AshStateMachine
for lifecycles, AshPaperTrail for audit, AshOban for durable execution and
AshAuthentication for identity.

Most of this repository was produced by generators (`mix igniter.new`,
`mix ash.gen.*`, `mix ash_authentication.add_strategy`,
`mix ash_phoenix.gen.live`, `mix ash.codegen`). That keeps the conventions
canonical and the handwritten parts easy to spot. The handwritten domain logic
is a few hundred lines of DSL.

## Architecture

```text
 Human browser            Services / agents            AI clients (planned)
      │                          │                            │
 LiveView + AshPhoenix     AshJsonApi (/api/v1)        AshAI MCP (allowlist)
      └──────────────┬───────────┴────────────────────────────┘
                     ▼
     Tauros.Accounts                 Tauros.Revenue
     User · Agent · ApiKey · Token   Customer · WalletAccount · (Invoice …)
                     │  actions · policies · validations · changes
                     ▼
               AshPostgres ──▶ PostgreSQL
```

- **Humans** sign in with a password (Argon2id) or a magic link, or get a bearer
  token from the API. They own agents and hold authority.
- **Agents** are AI or service principals. They authenticate with a generated API
  key (shown once, stored hashed, rotatable) and act only within their policies.
- **Ownership** (human → agent → customer / wallet account) is enforced by Ash
  policies, including on creates, and cannot be reassigned.

## Status

| | Capability | State |
| --- | --- | --- |
| Epic 1 | Human authentication; agents with generated API keys; customers owned through agents | ✅ rebuilt on Ash |
| Epic 2 | Agents register wallet accounts (address validated per settlement rail); humans review them | ✅ rebuilt on Ash |
| Epic 3 | Invoice drafts, state machine, human approval gate | next |
| Epic 4 | AshAI tools with an explicit allowlist | planned |
| Epics 5–9 | Audit, payments and reconciliation, data protection, semantic search, optional Arktos adapter | planned |

The original Phoenix-contexts implementation of Epics 1–2 is in the git history.
The behaviour was preserved; some API contracts were changed on purpose (see
[API.md](docs/API.md#changes-from-the-pre-ash-api)).

## Run it

You need the Erlang/Elixir versions in `.tool-versions` and PostgreSQL at
`localhost:5432` (user and password `postgres`):

```bash
docker run -d --name tauros-postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:17-alpine

mix setup        # deps, database, assets, demo seeds (prints a demo login and agent key)
mix phx.server   # http://localhost:4000 · API docs at /api/swaggerui
```

## Test it

```bash
mix test         # domain policies, API contract and LiveView flows
mix precommit    # warnings-as-errors, format, credo, sobelow, tests
```

CI also runs dependency audits and checks that migrations match the resources
(`mix ash.codegen --check`).

## What comes next

Epic 3 introduces the invoice: a draft an agent can create idempotently, an
AshStateMachine lifecycle that no actor can skip, and an approval bound to
the exact payload a human reviewed. Epic 4 then exposes the safe part of the
domain to AI clients through AshAI, and explicitly not the part that carries
authority. See the [roadmap](docs/ROADMAP.md).

---

Tauros is an educational blueprint, not financial, legal or compliance advice.
It is part of [CognoKratos](https://github.com/cognokratos), an open-source
initiative by [BelaZayka](https://www.belazayka.com).
