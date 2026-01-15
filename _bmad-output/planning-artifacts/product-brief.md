---
stepsCompleted:
  - 1
  - 2
  - 3
  - 4
  - 5
inputDocuments:
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/project-context-user.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/index.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/project-overview.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/architecture.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/development-guide.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/source-tree-analysis.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/component-inventory.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/api-contracts-web.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/data-models-web.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/docs/project-scan-report.json
date: 2026-01-15
author: Victor
---

# Product Brief: tauros-revenue

<!-- Content will be appended sequentially through collaborative workflow steps -->

## Executive Summary

Tauros Revenue is an educational blueprint for solo founders and indie hackers to build a simple, customizable blockchain invoicing system on Phoenix/LiveView. It extends a real codebase with three coordinated interfaces—LiveView UI for humans, JSON REST API for automation, and an MCP server for AI agents—so builders can learn how to deliver the same workflow across human, automated, and agentic contexts. The system emphasizes clarity, reliability, auditability, compliance, and privacy, while keeping blockchain handling intentionally lightweight (users provide addresses; the system never touches keys). Success is driven by adoption: founders can copy, adapt, and extend the blueprint, with AI agents creating invoices in minutes and humans reviewing instantly.

---

## Core Vision

### Problem Statement

Solo founders and indie hackers want to add blockchain-friendly invoicing, but existing tools are either end-user dashboard products or require deep blockchain mechanics. There’s no teachable, open-source blueprint that shows how to build a reliable invoicing workflow that works equally well for humans, automation tools, and AI agents.

### Problem Impact

Without a clear blueprint, founders lose time, build brittle one-off integrations, or avoid blockchain invoicing altogether. This slows down product iteration, increases compliance and audit risk, and makes AI-assisted workflows hard to trust or supervise.

### Why Existing Solutions Fall Short

Most crypto invoicing solutions optimize for end-user dashboards or assume users will handle wallet mechanics. They don’t teach how to build a coherent multi-interface product surface, and they rarely show how AI agents can operate safely with human oversight.

### Proposed Solution

Tauros Revenue is a teaching system: a minimal, comprehensible Phoenix/LiveView codebase that demonstrates a full invoicing workflow across LiveView UI, JSON REST API, and MCP. AI agents create invoices via MCP, humans approve and supervise in LiveView, and services integrate through a REST API—delivering a consistent, auditable workflow without managing private keys.

### Key Differentiators

- Teachable, open-source blueprint focused on clarity and extensibility
- Multi-interface design that aligns human, automated, and agentic workflows
- AI-first flow with explicit human supervision (“agent creates → human approves”)
- Lightweight blockchain handling that preserves privacy and reduces complexity
- Emphasis on reliability, auditability, and compliance best practices

## Target Users

### Primary Users

**Persona: Alex (Solo Founder)**  
Alex is a solo founder working from a laptop in a cafe, building products with a lean stack and limited time. Alex needs to invoice clients quickly across multiple chains and wallets without waiting on banks or juggling manual processes. Today, Alex relies on traditional invoicing tools and limited bank accounts, which slow down client billing and add friction.  
Alex’s motivation is speed and autonomy—being able to spin up accounts instantly and keep invoices moving without operational overhead. Success is when AI handles invoice generation across chains and accounts, and Alex only needs to review and approve.

### Secondary Users

**Persona: The AI Agent**  
The AI agent is the operational workhorse. It generates invoices across multiple blockchains and accounts based on client needs, applies routing preferences, and prepares invoices for human approval. The agent must stay within guardrails: it never handles private keys, only uses provided public addresses, and always produces a human-reviewable summary before sending or finalizing any invoice.

### User Journey

- **Discovery:** Finds Tauros Revenue via GitHub, articles, or tutorials focused on Phoenix/LiveView and blockchain invoicing.
- **Onboarding:** Clones the repo, explores the LiveView UI, and reads the documentation to understand the workflow.
- **Core Usage:** Configures accounts and customers, then lets the AI agent generate invoices across chains and accounts via MCP or API.
- **Success Moment (“Aha!”):** Realizes invoices can be created and routed across blockchains in minutes by AI, with simple human approval in LiveView.
- **Long-term:** Adapts the blueprint for their own product, extending workflows while keeping the system modular and auditable.

## Success Metrics

**User Success Metrics**
- Time to first AI-generated invoice (minutes)
- % of AI-generated invoices approved by humans without edits
- Volume of invoices created per active user (optional, if you want to track usage depth)

### Business Objectives

- Validate strong developer adoption and community pull
- Build a credible, teachable reference that founders can reuse and extend
- Attract inbound interest for support, consulting, or collaboration

### Key Performance Indicators

- GitHub stars and forks
- Number of questions asked (issues, discussions, emails)
- Number of people contacting you for help or guidance

## MVP Scope

### Core Features

- User registers a new Agent via LiveView UI
- User registers a new Customer via LiveView UI
- Wallet Service registers a new Account (public address) via API
- Agent creates new Invoices for Customers via MCP
- Agent queries Invoices using RAG via MCP
- Reporting Service updates Invoice status via API

### Out of Scope for MVP

- Direct blockchain connections or on-chain status syncing

### MVP Success Criteria

- AI agent can create valid invoices using previously provided customer and account data
- Humans can review and approve AI-generated invoices quickly

### Future Vision

- Full invoice lifecycle with real-time status updates via blockchain integrations
