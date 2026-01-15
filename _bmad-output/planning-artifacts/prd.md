---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-complete
inputDocuments:
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/product-brief.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/project-context-user.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/index.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/project-overview.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/architecture.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/component-inventory.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/api-contracts-web.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/data-models-web.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/development-guide.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/source-tree-analysis.md
documentCounts:
  briefs: 1
  research: 0
  brainstorming: 0
  projectDocs: 8
workflowType: 'prd'
lastStep: 11
project_name: tauros-revenue
user_name: Victor
date: 2026-01-15 16:56:53 CET
---

# Product Requirements Document - tauros-revenue

**Author:** Victor
**Date:** 2026-01-15 16:56:53 CET

## Executive Summary

Tauros Revenue is a teachable Phoenix/LiveView blueprint for blockchain-friendly invoicing with three coordinated interfaces: a LiveView UI for humans, a JSON REST API for services, and an MCP server for AI agents. It exists to make blockchain invoicing usable and trustworthy for solo founders and indie hackers without forcing them to master blockchain complexity. The workflow aligns human oversight with agentic automation: AI generates invoices and humans review/approve. The system never handles private keys—users provide public addresses—prioritizing clarity, reliability, auditability, compliance, and privacy.

### What Makes This Special

The core insight is that AI can make blockchain invoicing usable by removing complexity from the human workflow. The differentiator is a multi-interface design that keeps human, automated, and agentic flows consistent, with explicit “agent creates → human approves” supervision. It challenges the assumption that blockchain invoicing must be complex or wallet-centric, replacing it with a teachable, minimal, and auditable model.

## Project Classification

**Technical Type:** web_app + api_backend + developer_tool (MCP interface)
**Domain:** fintech (crypto payments / invoicing)
**Complexity:** high  
**Project Context:** Brownfield - extending existing system

This will shape our PRD to respect Phoenix/LiveView patterns while defining the new capabilities and integrations required across UI, API, and MCP.

## Success Criteria

### User Success

- Time to first AI-generated invoice: **< 5 minutes** from a fresh clone
- AI-generated invoices approved without edits: **≥ 95%**
- Invoices created via AI: **≥ 99%** of invoices
- “Worth it” moment: user generates **10 invoices in under 5 minutes**

### Business Success

- **3-month target:** establish a community of **100+ users**
- **12-month target:** reach **1,000 GitHub stars**
- Engagement: track **repo clones and forks** as primary signals

### Technical Success

- **Zero invoice data loss**
- **Full audit trail** for every invoice lifecycle change
- **99.99% uptime**

### Measurable Outcomes

- Median time-to-first-invoice < 5 minutes (fresh clone → invoice generated)
- ≥ 95% AI invoice approvals without edits
- ≥ 99% invoices created via AI
- 100+ users by month 3; 1,000 stars by month 12
- Clones/forks trending upward month-over-month
- 0 data loss incidents; complete audit log coverage

## Product Scope

### MVP - Minimum Viable Product

- User registers a new **Agent**
- User registers a new **Customer**
- Wallet Service registers a new **Account**
- Agent creates new **Invoice** for **Customer** via MCP
- Agent queries **Invoices** using RAG via MCP
- Reporting Service updates **Invoice** status via API

### Growth Features (Post-MVP)

- **Blockchain integrations** (on-chain status updates, confirmations, chain‑specific flows)

### Vision (Future)

- **Fully AI-driven finance management** with metrics, insights, and forecasts

## User Journeys

**Journey 1: Alex — “From Fresh Clone to First Invoice” (Success Path)**  
Alex is a solo founder who wants blockchain invoicing without wallet complexity. He clones Tauros Revenue, runs setup, and opens the LiveView UI. In minutes, he registers an Agent and a Customer, then connects a wallet account via the provided flow.  
Alex triggers invoice generation through the AI agent. The invoice appears in LiveView with a clear summary, routing details, and a human-readable audit trail. He approves it in one click and watches the invoice move into “Pending.”  
The breakthrough comes when Alex realizes he can generate 10 invoices in under five minutes, without touching private keys. He feels relief: this is finally usable.

**Journey 2: Alex — “The First Correction” (Edge Case)**  
Alex reviews an AI-generated invoice and notices the description is off. Instead of abandoning automation, he edits the invoice, adds a note, and re-approves.  
The system captures the edit, preserves a full audit trail, and the AI agent learns the correction pattern (if applicable). Alex stays in control while keeping AI in the loop. He trusts the system because he sees both the original and corrected versions clearly.

**Journey 3: The AI Agent — “Invoice Creation With Guardrails”**  
The AI agent receives a task to create a new invoice for a specific customer. It fetches customer and account data, applies the correct public address, and generates the invoice.  
Before it can finalize, it produces a human-reviewable summary and submits it for Alex’s approval. The agent never handles private keys and never bypasses the approval gate.  
Success is a clean handoff: “Agent creates → human approves,” with all actions logged for auditability.

**Journey 4: The AI Agent — “RAG-Powered Invoice Query”**  
The agent is asked to answer: “Show overdue invoices for Customer X and summarize payment history.”  
It runs a RAG query across invoice data and returns a concise summary with references. Alex can validate the output quickly, using the audit trail to verify the agent’s claims.  
This builds trust: AI provides speed, the system provides verification.

### Journey Requirements Summary

- **LiveView onboarding:** register Agent, Customer, Account quickly
- **Approval workflow:** AI-generated invoice review + one-click approve
- **Editable invoices:** human correction without losing audit trail
- **Strict guardrails:** agent cannot bypass approval or access keys
- **RAG query support:** searchable invoice history with traceable outputs
- **Auditability:** immutable change history for invoices

## Domain-Specific Requirements

### Fintech Compliance & Regulatory Overview

Tauros Revenue operates in a fintech/crypto context but is explicitly a **blueprint**, not a compliance product. The system should provide **guidelines and extensible patterns** so builders can adapt to their regional requirements (US/EU/other) without hard-coding jurisdiction-specific rules.

### Key Domain Concerns

- **Regional compliance:** Provide clear guidance and extension points for KYC/AML, tax reporting, and jurisdictional rules.
- **Security standards:** Favor “good security without over-engineering,” prioritizing accessible patterns.
- **Audit requirements:** Maintain a complete, immutable history of who/what/when for invoice actions.
- **Fraud prevention:** Not in MVP; document as a future consideration.
- **Data protection:** Encrypt sensitive data and enable GDPR-aligned practices.

### Compliance Requirements

- Publish **builder guidance** on how to adapt for regional compliance regimes.
- Provide a **compliance checklist** section (non-binding) to help builders evaluate requirements.

### Industry Standards & Best Practices

- Baseline security practices (OWASP-style, least privilege, audit logs).
- Data retention defaults plus manual purge workflow.

### Required Expertise & Validation

- Builders should validate requirements with local legal/compliance experts.
- Provide explicit disclaimers that this is an educational blueprint.

### Implementation Considerations

- Encryption at rest for sensitive fields and secrets.
- Audit trail retention: **who/what/when**, retained until manual purge.
- GDPR support: data export and purge patterns.

### Compliance Matrix

- Region → Required controls → Implementer action items (guideline template)

## Innovation & Novel Patterns

### Detected Innovation Areas

- **AI as an adoption layer**: Using AI to make blockchain invoicing usable and low-friction for professionals who otherwise rely on conventional banks.
- **Multi-interface parity**: A single workflow expressed consistently across LiveView (human), REST (services), and MCP (agents).
- **Human-supervised agents**: “Agent creates → human approves” as a repeatable safety pattern.

### Market Context & Competitive Landscape

Most crypto invoicing tools emphasize dashboards or wallet mechanics. Few present an **AI-first, human-supervised** workflow designed to reduce operational friction for professionals.

### Validation Approach

- Measure time-to-first-invoice (< 5 minutes) and 10-invoice success under supervision.
- Track approval-without-edits rate (≥ 95%) as a signal of AI usability.
- Validate that users can replace bank-based invoicing flows without increased error rates.

### Risk Mitigation

- If AI outputs are unreliable, default to guided templates in LiveView.
- Preserve human approval gates and audit logs for every action.
- Keep blockchain handling lightweight to avoid UX regression.

## API Backend Specific Requirements

### Project-Type Overview

Tauros Revenue is primarily an **API backend** with three surfaces: Admin REST, Public REST, and MCP tools. The API layer is the primary interface because AI agents handle ~99% of workflow execution, with humans supervising.

### Technical Architecture Considerations

- Separate **admin** (Bearer token) and **agent/service** (X-API-KEY) authentication flows.
- Maintain strict boundaries: admin endpoints create Agents/Customers; agent keys act on operational data (accounts, invoices, status).
- MCP endpoint versioned at `/mcp/v1` with tool definitions as the primary agent interface.

### Endpoint Specification

**Admin REST (Bearer Token)**
- `POST /api/admin/v1/agents` → register agent
- `POST /api/admin/v1/customers` → register customer

**Public REST (X-API-KEY)**
- `POST /api/v1/accounts` → register account
- `PATCH /api/v1/invoices/:id` → update invoice status

**MCP Tools (X-API-KEY, /mcp/v1)**
- `create_invoice` → generate invoice for customer wallet
- `query_invoices` → RAG search across invoices

### Authentication Model

- **Admin:** `Authorization: Bearer <token>`
- **Agent/Service:** `X-API-KEY: <agent api key>`
- API key rotation/expiry not required initially (explicitly out of scope unless added later).

### Data Schemas & Formats

- **REST:** JSON payloads and responses
- **MCP:** Text inputs/outputs
- Use consistent error envelopes across REST endpoints

### Error Codes

- Standard HTTP error codes for REST (400/401/403/404/422/500)
- MCP tool errors returned as structured text responses with clear failure reasons

### Rate Limits

- None initially; leave as future enhancement

### API Docs & Reference Examples

- Provide **reference examples** for REST and MCP usage
- Include minimal examples for agent key usage and admin token flows

### Implementation Considerations

- Version all REST endpoints under `/v1` and `/api/admin/v1`
- Version MCP under `/mcp/v1`
- Ensure audit logging for all API actions (who/what/when)

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Platform MVP  
**Resource Requirements:** Cross-functional team with UI, API, MCP, DB, and RAG expertise (medium scope)

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Alex “Fresh Clone → First Invoice”
- Alex “First Correction”
- AI Agent “Invoice Creation with Guardrails”
- AI Agent “RAG Invoice Query”

**Must-Have Capabilities:**
- Account registration via public API
- Agent-driven invoice creation + human approval
- RAG querying over invoices
- Audit trail (who/what/when) with manual purge
- Admin endpoints to register agents and customers

### Post-MVP Features

**Phase 2 (Post-MVP):**
- Analytics dashboards
- Forecasting
- Recommendations

**Phase 3 (Expansion):**
- Blockchain integrations (status updates, confirmations, chain-specific flows)
- Fully AI-driven finance management with metrics and forecasts

### Risk Mitigation Strategy

**Technical Risks:** Over-engineering → constrain MVP to minimal surface area and keep compliance guidance non-binding  
**Market Risks:** Blockchain/AI mistrust → emphasize human approval gates and transparent auditability  
**Resource Risks:** Medium scope → focus on core API + MCP flows first, delay growth features

## Functional Requirements

### User & Identity Management
- FR1: Admin users can authenticate with a Bearer token to access admin endpoints.
- FR2: Admin users can register a new Agent with a name and API key.
- FR3: Admin users can register a new Customer with name and email.
- FR4: The system can associate Customers with the Agent who owns them.

### Account & Wallet Management
- FR5: Agent services can register a new Account using an Agent API key.
- FR6: The system can store wallet name, public address, and currency for an Account.
- FR7: The system can associate Accounts with the Agent who owns them.
- FR8: Admin users can view Accounts for their Agents in the UI.

### Invoice Creation & Approval
- FR9: AI agents can create an Invoice for a specified Customer.
- FR10: Invoices can include description, amount, currency, and payment destination.
- FR11: The system can enforce that AI-created invoices require human approval.
- FR12: Admin users can review AI-generated invoices before approval.
- FR13: Admin users can approve or reject AI-generated invoices.
- FR14: Admin users can edit an AI-generated invoice before approval.

### Invoice Status & Lifecycle
- FR15: Services can update invoice status via the public REST API using Agent API keys.
- FR16: The system can track invoice status transitions (Pending, Paid, Overdue).
- FR17: The system can display invoice status changes in the UI.

### Invoice Search & RAG
- FR18: AI agents can query invoices by description using the MCP tool.
- FR19: The system can return invoice query results with human-readable summaries.
- FR20: Admin users can review AI query outputs in the UI.

### MCP Agent Interface
- FR21: The system can authenticate MCP tool usage with Agent API keys.
- FR22: The system can expose MCP tools under a versioned `/mcp/v1` interface.
- FR23: MCP tools can return success or failure messages for agent actions.

### Auditability & Compliance
- FR24: The system can record an immutable audit log for invoice lifecycle actions.
- FR25: The audit log can capture who performed the action, what changed, and when.
- FR26: Admin users can view audit history for an invoice.
- FR27: The system can retain audit logs until a manual purge is triggered.

### Data Governance & Privacy
- FR28: The system can encrypt sensitive fields at rest.
- FR29: The system can support GDPR-aligned data export on request.
- FR30: The system can support GDPR-aligned data purge on request.

### Documentation & Guidance
- FR31: The system can provide reference examples for REST API usage.
- FR32: The system can provide reference examples for MCP tool usage.
- FR33: The system can provide guidance for regional compliance customization.

### Platform Operations
- FR34: Admin users can access a LiveView UI to supervise agent activity.
- FR35: The system can surface agent actions and invoice events to the UI for review.

## Non-Functional Requirements

### Performance
- p95 response time for REST and MCP requests is **< 500ms**

### Security
- Sensitive data is **encrypted at rest**
- All external traffic uses **TLS in transit**
- Access to admin endpoints is restricted to authenticated Bearer tokens
- Access to agent/service endpoints and MCP tools requires a valid Agent API key

### Reliability
- **99.99% uptime** for API and MCP interfaces

### Scalability
- Support at least **100 active agents** and **1,000 requests/day** without degradation

### Integration
- REST and MCP interfaces remain stable within **/v1** contracts
- Backward-compatible changes only within the same major version
