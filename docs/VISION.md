# Vision

## Ταύρος Revenue: agentic financial workflow engineering

> How can AI safely take part in financial workflows without the model being
> given financial authority?

Tauros is an open-source, educational revenue application covering customers,
invoices, approvals, payments and reconciliation, in which AI agents do most of
the operational work and humans keep the authority. The lesson is in the
architecture: the same domain actions serve a human UI, a REST API and AI tools,
and deterministic code decides what is allowed, whoever is asking.

## The problem it teaches

Teams adding AI to finance usually choose between two bad options:

- **The model is trusted**, so prompts become the access-control layer. That fails
  the first time the model is wrong, confused or manipulated.
- **The model is sandboxed into uselessness**, so humans redo the work.

Tauros shows a third way. Give the agent **broad capability** (read, search,
draft, propose, retry) and **no authority** (approve, issue, mark paid). Enforce
the line with policies, state machines and explicit tool allowlists. See
[AI-AUTHORITY.md](AI-AUTHORITY.md).

## Its place in CognoKratos

[CognoKratos](https://github.com/cognokratos) projects are complementary. Each
teaches one layer and avoids repeating the others.

| Project | Teaches |
| --- | --- |
| [simple-agent-template](https://github.com/cognokratos/simple-agent-template) | Production agent engineering: trust boundaries, MCP, guardrails, observability, evaluation, approvals |
| [etf-research-agent](https://github.com/cognokratos/etf-research-agent) | Governed decision engineering: policy-as-data, evidence, uncertainty, decision authority, system-level evaluation |
| [sophos-agent](https://github.com/cognokratos/sophos-agent) | Agent construction: loops, memory, reflection, durable and local-first orchestration |
| [arktos-wallet](https://github.com/cognokratos/arktos-wallet) | Secure financial and cryptographic capabilities: custody, keys, signing, wallet boundaries |
| **tauros-revenue** | **Agentic financial workflow engineering**: domain modelling, policies, human authority, state machines, idempotency, auditability, eventual consistency, reconciliation |

The Rust projects show how low-level infrastructure and protocols work, MCP
included. **Tauros shows how Elixir and Ash compose sophisticated business and
agentic applications with very little handwritten infrastructure.** That is why
Tauros uses AshAI for its AI surface instead of a hand-built MCP server.

Two boundaries matter most:

- **Tauros knows financial intent. Arktos knows cryptographic authority.**
  Tauros models contracts, customers, invoices, approvals, receivables, payments
  and reconciliation. It never holds keys or signs. A future Arktos integration
  is an optional adapter (see [ROADMAP.md](ROADMAP.md#epic-9-optional-arktos-integration)).
- **Tauros is not an agent framework.** The agents that call it can be built
  with any of the other projects. Tauros is the system of record they are not
  allowed to overrule.

## Why Elixir and Ash

- **Ash expresses business rules as data.** Attributes, actions, policies,
  validations, changes and calculations are declarations the framework enforces
  identically for every caller. The same declarations generate the JSON:API,
  the forms, the migrations and, with AshAI, the tool definitions.
- **The extensions cover exactly the ideas Tauros teaches:** AshStateMachine for
  lifecycles, AshPaperTrail for audit, AshOban for durable execution,
  AshAuthentication for identity, AshCloak for PII and AshAI for agent tools.
- **The BEAM suits workflows**: supervised processes, durable jobs on
  PostgreSQL, real-time UI with LiveView, and no separate frontend to secure.
- **Generators keep code canonical.** Most of this repository was produced by
  `mix igniter.new`, `mix ash.gen.*`, `mix ash_authentication.*` and
  `mix ash_phoenix.gen.live`, so a reader can tell the conventions apart from the
  decisions.

## Who it is for

- **Engineers** learning how to put AI into a workflow where mistakes cost money.
- **Elixir developers** who want a realistic Ash application to read end to end.
- **Founders and indie builders** who need a starting point for AI-assisted
  invoicing that accepts stablecoin, crypto and bank payments.

The original product persona still applies. *Alex*, a solo founder, wants AI to
prepare invoices across chains and bank accounts while they spend about five
minutes a day reviewing and approving. The agent does the work; Alex holds the
authority.

## Principles

1. **AI capability does not imply financial authority.**
2. **Authoritative state lives in the application**, never in a conversation.
3. **Keep intent, authority and execution separate.**
4. **Every financial command is idempotent and audited.**
5. **External money movement is eventually consistent**; reconcile, don't assume.
6. **No private keys, ever.** Public addresses only.
7. **Write the least code that keeps the financial invariants obvious.**

## Non-goals

Custody and signing, direct blockchain node integration, jurisdiction-specific
compliance logic, fraud scoring, and being a hosted product. Tauros is a
blueprint and is not legal, tax or compliance advice.
