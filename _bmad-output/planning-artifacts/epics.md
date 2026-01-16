---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
inputDocuments:
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/prd.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/planning-artifacts/architecture.md
  - /Users/victornitu/Projects/CognoKratos/tauros-revenue/_bmad-output/project-context.md
---

# tauros-revenue - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for tauros-revenue, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Admin users can authenticate with a Bearer token to access admin endpoints.
FR2: Admin users can register a new Agent with a name and API key.
FR3: Admin users can register a new Customer with name and email.
FR4: The system can associate Customers with the Agent who owns them.
FR5: Agent services can register a new Account using an Agent API key.
FR6: The system can store wallet name, public address, and currency for an Account.
FR7: The system can associate Accounts with the Agent who owns them.
FR8: Admin users can view Accounts for their Agents in the UI.
FR9: AI agents can create an Invoice for a specified Customer.
FR10: Invoices can include description, amount, currency, and payment destination.
FR11: The system can enforce that AI-created invoices require human approval.
FR12: Admin users can review AI-generated invoices before approval.
FR13: Admin users can approve or reject AI-generated invoices.
FR14: Admin users can edit an AI-generated invoice before approval.
FR15: Services can update invoice status via the public REST API using Agent API keys.
FR16: The system can track invoice status transitions (Pending, Paid, Overdue).
FR17: The system can display invoice status changes in the UI.
FR18: AI agents can query invoices by description using the MCP tool.
FR19: The system can return invoice query results with human-readable summaries.
FR20: Admin users can review AI query outputs in the UI.
FR21: The system can authenticate MCP tool usage with Agent API keys.
FR22: The system can expose MCP tools under a versioned `/mcp/v1` interface.
FR23: MCP tools can return success or failure messages for agent actions.
FR24: The system can record an immutable audit log for invoice lifecycle actions.
FR25: The audit log can capture who performed the action, what changed, and when.
FR26: Admin users can view audit history for an invoice.
FR27: The system can retain audit logs until a manual purge is triggered.
FR28: The system can encrypt sensitive fields at rest.
FR29: The system can support GDPR-aligned data export on request.
FR30: The system can support GDPR-aligned data purge on request.
FR31: The system can provide reference examples for REST API usage.
FR32: The system can provide reference examples for MCP tool usage.
FR33: The system can provide guidance for regional compliance customization.
FR34: Admin users can access a LiveView UI to supervise agent activity.
FR35: The system can surface agent actions and invoice events to the UI for review.

### NonFunctional Requirements

NFR1: p95 response time for REST and MCP requests is < 500ms.
NFR2: Sensitive data is encrypted at rest.
NFR3: All external traffic uses TLS in transit.
NFR4: Access to admin endpoints is restricted to authenticated Bearer tokens.
NFR5: Access to agent/service endpoints and MCP tools requires a valid Agent API key.
NFR6: 99.99% uptime for API and MCP interfaces.
NFR7: Support at least 100 active agents and 1,000 requests/day without degradation.
NFR8: REST and MCP interfaces remain stable within /v1 contracts; changes are backward compatible within the same major version.

### Additional Requirements

- Phoenix 1.8 + LiveView 1.1 with Ecto/Postgres as the application stack.
- Use Req for HTTP calls.
- Use pgvector for invoice embeddings with Arcana and an Ollama-based embedder.
- Use Anubis MCP server for agent tools; MCP endpoint versioned at `/mcp/v1`.
- Never handle private keys; public addresses only.
- Docker Compose for app + pgvector; release via `mix phx.gen.release --docker`.
- Enforce `agent_id` scoping at DB level via foreign keys and constraints.
- Separate `invoice_audit_logs` table for immutable audit history.
- Separate `invoice_embeddings` table for RAG; update embeddings on invoice create/update.
- Admin auth via Bearer token; agent auth via single API key hashed at rest.
- REST error envelope `{error: %{code, message, details}}`; MCP errors as structured text with `code` and `message`.
- Version REST endpoints under `/api/v1` and `/api/admin/v1`.
- Contexts are the source of truth for UI, REST, and MCP; no direct schema writes from controllers/LiveViews.
- LiveView UI per domain (Agents, Customers, Accounts, Invoices, Audit); inline approve/reject in invoice list; audit tab for history.
- Encrypt API keys and PII at rest; no blanket encryption for all fields.
- Provide OpenAPI spec plus markdown examples for API docs.
- Logger to stdout; basic CI tests in GitHub Actions.

### FR Coverage Map

### FR Coverage Map

FR1: Epic 1 - Admin authentication and access.
FR2: Epic 1 - Register agents with ownership.
FR3: Epic 1 - Register customers with ownership.
FR4: Epic 1 - Associate customers to owning agents.
FR5: Epic 2 - Register wallet accounts via agent key.
FR6: Epic 2 - Store wallet account details.
FR7: Epic 2 - Associate accounts to owning agents.
FR8: Epic 2 - Admin account visibility in UI.
FR9: Epic 3 - Agent invoice creation.
FR10: Epic 3 - Invoice fields capture.
FR11: Epic 3 - Enforce human approval.
FR12: Epic 3 - Admin review flow.
FR13: Epic 3 - Approve/reject invoices.
FR14: Epic 3 - Edit invoice pre-approval.
FR15: Epic 4 - Service-driven status updates.
FR16: Epic 4 - Track status transitions.
FR17: Epic 4 - UI status visibility.
FR18: Epic 6 - MCP invoice querying (RAG).
FR19: Epic 6 - Query summaries.
FR20: Epic 6 - Admin review of query outputs.
FR21: Epic 3 - MCP tool auth for create.
FR22: Epic 3 - MCP versioned interface.
FR23: Epic 3 - MCP success/failure responses.
FR24: Epic 5 - Immutable audit logging.
FR25: Epic 5 - Audit log who/what/when.
FR26: Epic 5 - Audit history visibility.
FR27: Epic 5 - Audit retention and purge control.
FR28: Epic 5 - Encryption at rest for sensitive fields.
FR29: Epic 5 - GDPR export support.
FR30: Epic 5 - GDPR purge support.
FR31: Epic 7 - REST API reference examples.
FR32: Epic 7 - MCP tool reference examples.
FR33: Epic 5 - Regional compliance guidance.
FR34: Epic 7 - Admin supervision UI.
FR35: Epic 7 - Surface agent actions/events in UI.

## Epic List

### Epic 1: Admin Setup & Ownership Foundations
Admins can authenticate, create Agents and Customers, and establish ownership boundaries.
**FRs covered:** FR1, FR2, FR3, FR4

### Epic 2: Wallet Account Onboarding
Agents can register wallet accounts, store public addresses, and admins can review accounts in UI.
**FRs covered:** FR5, FR6, FR7, FR8

### Epic 3: Invoice Creation With Human Approval (LiveView + MCP Create)
Agents generate invoices through MCP, admins review/edit, and approvals are enforced.
**FRs covered:** FR9, FR10, FR11, FR12, FR13, FR14, FR21, FR22, FR23

### Epic 4: Invoice Lifecycle Updates & Status Visibility
Services update invoice status; transitions and updates are visible in the UI.
**FRs covered:** FR15, FR16, FR17

### Epic 5: Auditability & Compliance Controls
Immutable audit logging, visibility, retention, encryption, GDPR export/purge, and compliance guidance.
**FRs covered:** FR24, FR25, FR26, FR27, FR28, FR29, FR30, FR33

### Epic 6: RAG Invoice Querying & Agent Insights
Agents query invoices via MCP with summarized results, with admin review of outputs.
**FRs covered:** FR18, FR19, FR20

### Epic 7: Admin Supervision UI & Developer Reference
Admins supervise agent activity in LiveView and have REST/MCP reference examples.
**FRs covered:** FR31, FR32, FR34, FR35

## Epic 1: Admin Setup & Ownership Foundations

Admins can authenticate, create Agents and Customers, and establish ownership boundaries.

### Story 1.1: Admin Authentication for Admin Endpoints

As an admin user,
I want to authenticate with a Bearer token for admin endpoints,
So that only authorized admins can manage core resources.

**Acceptance Criteria:**

**Given** an admin request to `/api/admin/v1/*` without a valid Bearer token
**When** the request is processed
**Then** the API responds with a standardized `{error: %{code, message, details}}`
**And** no protected action is performed

**Given** an admin request with a valid Bearer token
**When** the request is processed
**Then** the API authorizes the request
**And** the action proceeds as normal

### Story 1.2: Admin Registers Agent

As an admin user,
I want to register a new Agent with a name and API key,
So that the Agent can act on behalf of the admin in operational flows.

**Acceptance Criteria:**

**Given** a valid Bearer token and a request with a name for a new Agent
**When** the admin submits the create-agent request
**Then** a new Agent is created with a unique API key
**And** the API key is stored hashed at rest

**Given** a request missing required Agent fields
**When** the request is processed
**Then** the API returns a standardized `{error: %{code, message, details}}`
**And** no Agent record is created

### Story 1.3: Admin Registers Customer

As an admin user,
I want to register a new Customer with name and email,
So that the Agent can create invoices for that customer.

**Acceptance Criteria:**

**Given** a valid Bearer token and a request with customer name and email
**When** the admin submits the create-customer request
**Then** a new Customer is created
**And** the Customer is associated with the owning Agent

**Given** a request missing required Customer fields
**When** the request is processed
**Then** the API returns a standardized `{error: %{code, message, details}}`
**And** no Customer record is created

### Story 1.4: Enforce Customer Ownership by Agent

As an admin user,
I want customers to be scoped to their owning Agent,
So that data access respects ownership boundaries.

**Acceptance Criteria:**

**Given** a Customer record
**When** it is queried or referenced in admin operations
**Then** the system enforces `agent_id` scoping at the query boundary
**And** access outside the owning Agent is prevented

**Given** an attempt to associate a Customer with a different Agent
**When** the system validates the association
**Then** it rejects invalid ownership changes
**And** returns a standardized error response

## Epic 2: Wallet Account Onboarding

Agents can register wallet accounts, store public addresses, and admins can review accounts in UI.

### Story 2.1: Agent Registers Wallet Account

As an agent service,
I want to register a new wallet account using an Agent API key,
So that I can direct invoice payments to a public address.

**Acceptance Criteria:**

**Given** a valid Agent API key and a request with wallet name, public address, and currency
**When** the agent submits the create-account request
**Then** a new Account is created
**And** it is associated with the owning Agent

**Given** a request missing required account fields
**When** the request is processed
**Then** the API returns a standardized `{error: %{code, message, details}}`
**And** no Account record is created

### Story 2.2: Admin Views Accounts in UI

As an admin user,
I want to view Accounts for my Agents in the LiveView UI,
So that I can verify wallet destinations and ownership.

**Acceptance Criteria:**

**Given** an admin user in the UI
**When** they navigate to Accounts
**Then** they see a list of Accounts scoped to their Agents
**And** each account shows wallet name, public address, and currency

**Given** no Accounts exist for the admin’s Agents
**When** the Accounts view loads
**Then** the UI shows an empty state
**And** no accounts are displayed

## Epic 3: Invoice Creation With Human Approval (LiveView + MCP Create)

Agents generate invoices through MCP, admins review/edit, and approvals are enforced.

### Story 3.1: Agent Creates Invoice via MCP

As an agent service,
I want to create an invoice for a specified customer via MCP,
So that invoices can be generated programmatically with human oversight.

**Acceptance Criteria:**

**Given** a valid Agent API key and MCP request with customer, description, amount, currency, and payment destination
**When** the agent submits the create-invoice tool to `/mcp/v1`
**Then** a new Invoice is created in a pending state
**And** the system returns a success response via MCP

**Given** an invalid MCP request (missing or invalid invoice fields)
**When** the request is processed
**Then** the system returns a structured MCP error with `code` and `message`
**And** no Invoice record is created

### Story 3.2: Admin Reviews Pending Invoice

As an admin user,
I want to review AI-generated invoices in the UI,
So that I can approve or reject them with context.

**Acceptance Criteria:**

**Given** pending invoices exist
**When** the admin opens the invoices list
**Then** pending invoices are visible with key details
**And** each invoice shows its status and audit summary

**Given** an invoice is pending review
**When** the admin opens its detail view
**Then** they can see full invoice details needed to decide
**And** no approval occurs without an explicit action

### Story 3.3: Admin Approves or Rejects Invoice

As an admin user,
I want to approve or reject a pending invoice,
So that only reviewed invoices move forward.

**Acceptance Criteria:**

**Given** a pending invoice
**When** the admin selects approve
**Then** the invoice status changes to approved
**And** the action is recorded for auditability

**Given** a pending invoice
**When** the admin selects reject
**Then** the invoice is marked rejected
**And** the action is recorded for auditability

### Story 3.4: Admin Edits Invoice Before Approval

As an admin user,
I want to edit an AI-generated invoice before approval,
So that corrections can be made without breaking the approval flow.

**Acceptance Criteria:**

**Given** a pending invoice
**When** the admin edits invoice fields
**Then** the changes are saved
**And** the invoice remains pending until approved

**Given** an edit attempt with invalid invoice data
**When** the update is processed
**Then** the system returns a validation error
**And** the invoice is not updated

### Story 3.5: Enforce Human Approval Gate

As an admin user,
I want AI-created invoices to require explicit human approval,
So that automated invoices never bypass review.

**Acceptance Criteria:**

**Given** an invoice created by an agent
**When** it is saved
**Then** it is marked as pending and not approved by default
**And** it cannot be treated as approved without a human action

**Given** an attempt to bypass approval (via API or UI)
**When** the system validates the action
**Then** it rejects the attempt
**And** returns a standardized error response

## Epic 4: Invoice Lifecycle Updates & Status Visibility

Services update invoice status; transitions and updates are visible in the UI.

### Story 4.1: Service Updates Invoice Status via API

As a service,
I want to update invoice status via the public REST API using an Agent API key,
So that invoice payment states stay current.

**Acceptance Criteria:**

**Given** a valid Agent API key and a request to update an invoice status
**When** the service submits the update
**Then** the invoice status is updated
**And** the response confirms the new status

**Given** an invalid status update or missing invoice
**When** the request is processed
**Then** the API returns a standardized `{error: %{code, message, details}}`
**And** no status change occurs

### Story 4.2: Track Invoice Status Transitions

As a service,
I want the system to track invoice status transitions (Pending, Paid, Overdue),
So that status history is consistent and auditable.

**Acceptance Criteria:**

**Given** an invoice status update
**When** the system processes the change
**Then** it validates the transition against allowed statuses
**And** stores the new status

**Given** a request to set an unsupported status
**When** the update is processed
**Then** the API returns a standardized error response
**And** the status remains unchanged

### Story 4.3: Display Invoice Status Changes in UI

As an admin user,
I want to see invoice status changes in the UI,
So that I can track payment progress at a glance.

**Acceptance Criteria:**

**Given** invoices exist with status history
**When** the admin views the invoice list
**Then** each invoice displays its current status
**And** status changes are visible in the UI

**Given** an invoice detail view
**When** the admin opens it
**Then** they can see status transition history
**And** the timeline reflects recorded changes

## Epic 5: Auditability & Compliance Controls

Immutable audit logging, visibility, retention, encryption, GDPR export/purge, and compliance guidance.

### Story 5.1: Record Immutable Audit Log for Invoice Actions

As an admin user,
I want the system to record an immutable audit log for invoice lifecycle actions,
So that every change is traceable and trustworthy.

**Acceptance Criteria:**

**Given** an invoice is created, updated, approved, rejected, or status-changed
**When** the action is processed
**Then** an audit log entry is recorded with who/what/when
**And** the log entry cannot be updated or deleted

**Given** an attempt to modify or delete an audit log entry
**When** the system validates the action
**Then** it rejects the attempt
**And** returns a standardized error response

### Story 5.2: View Audit History for an Invoice

As an admin user,
I want to view audit history for an invoice,
So that I can verify who changed what and when.

**Acceptance Criteria:**

**Given** an invoice with audit entries
**When** the admin opens the audit view
**Then** they see a chronological list of audit events
**And** each entry shows who, what, and when

**Given** an invoice with no audit entries
**When** the admin opens the audit view
**Then** the UI shows an empty state
**And** no audit events are displayed

### Story 5.3: Retain Audit Logs Until Manual Purge

As an admin user,
I want audit logs to be retained until a manual purge is triggered,
So that history remains intact by default.

**Acceptance Criteria:**

**Given** audit logs exist
**When** no purge is requested
**Then** audit logs remain available indefinitely
**And** no automatic deletion occurs

**Given** a manual purge request
**When** the system processes it
**Then** the specified audit logs are removed
**And** the purge action is itself recorded

### Story 5.4: Encrypt Sensitive Fields at Rest

As an admin user,
I want sensitive fields (API keys and PII) encrypted at rest,
So that data is protected if storage is compromised.

**Acceptance Criteria:**

**Given** an Agent API key or PII field is stored
**When** the record is persisted
**Then** the field is encrypted at rest
**And** decrypted only for authorized access paths

**Given** a non-sensitive field
**When** it is stored
**Then** it is not encrypted by default
**And** remains accessible for normal queries

### Story 5.5: GDPR Export of Customer Data

As an admin user,
I want to export customer data on request,
So that I can comply with GDPR access requirements.

**Acceptance Criteria:**

**Given** a valid export request for a customer
**When** the system processes it
**Then** it returns all stored data for that customer
**And** includes related invoices and audit history

**Given** an invalid or unauthorized export request
**When** the system validates it
**Then** it returns a standardized error response
**And** no data is exported

### Story 5.6: GDPR Purge of Customer Data

As an admin user,
I want to purge customer data on request,
So that I can comply with GDPR deletion requirements.

**Acceptance Criteria:**

**Given** a valid purge request for a customer
**When** the system processes it
**Then** the customer’s data is removed or anonymized
**And** the purge action is recorded for auditability

**Given** an invalid or unauthorized purge request
**When** the system validates it
**Then** it returns a standardized error response
**And** no data is purged

### Story 5.7: Compliance Guidance for Regional Rules

As a builder,
I want guidance for regional compliance customization,
So that I can adapt the blueprint to local regulations.

**Acceptance Criteria:**

**Given** a builder reviews the documentation
**When** they look for compliance guidance
**Then** they find a checklist and extension points for regional rules
**And** the guidance is explicitly non-binding

**Given** the system ships with documentation
**When** it is published
**Then** compliance guidance is included
**And** it references the need for local legal validation

## Epic 6: RAG Invoice Querying & Agent Insights

Agents query invoices via MCP with summarized results, with admin review of outputs.

### Story 6.1: Agent Queries Invoices via MCP

As an agent service,
I want to query invoices by description using MCP,
So that I can retrieve relevant invoice data programmatically.

**Acceptance Criteria:**

**Given** a valid Agent API key and a query request
**When** the agent submits the MCP query tool
**Then** the system returns matching invoices
**And** the response includes a concise summary

**Given** a query with no matches
**When** it is processed
**Then** the system returns an empty result set
**And** includes a clear “no matches” summary

### Story 6.2: Admin Reviews MCP Query Outputs

As an admin user,
I want to review MCP query outputs in the UI,
So that I can verify AI summaries against the source data.

**Acceptance Criteria:**

**Given** an MCP query result exists
**When** the admin opens the related invoice view
**Then** the UI shows the AI summary alongside source invoices
**And** the admin can verify the summary

**Given** an MCP query produces no results
**When** the admin views the summary area
**Then** the UI displays a clear “no results” state
**And** no stale data is shown

## Epic 7: Admin Supervision UI & Developer Reference

Admins supervise agent activity in LiveView and have REST/MCP reference examples.

### Story 7.1: Admin Supervision of Agent Activity in UI

As an admin user,
I want to supervise agent activity in the LiveView UI,
So that I can monitor agent actions and invoice events in one place.

**Acceptance Criteria:**

**Given** agent actions and invoice events exist
**When** the admin opens the supervision view
**Then** the UI shows a scoped list of recent agent actions and events
**And** entries include who acted, what happened, and when

**Given** no agent activity exists
**When** the supervision view loads
**Then** the UI shows an empty state
**And** no events are displayed

### Story 7.2: Publish REST API Reference Examples

As a builder,
I want REST API reference examples,
So that I can integrate services correctly.

**Acceptance Criteria:**

**Given** the REST API documentation
**When** a builder reviews it
**Then** they find example requests and responses for admin and public endpoints
**And** the examples include required auth headers

**Given** the docs are published
**When** they are updated
**Then** the examples remain consistent with `/api/v1` and `/api/admin/v1` contracts
**And** outdated examples are removed

### Story 7.3: Publish MCP Tool Reference Examples

As a builder,
I want MCP tool reference examples,
So that I can integrate agent workflows correctly.

**Acceptance Criteria:**

**Given** the MCP documentation
**When** a builder reviews it
**Then** they find example requests and responses for MCP tools
**And** the examples include required X-API-KEY usage

**Given** the docs are published
**When** they are updated
**Then** the examples remain consistent with `/mcp/v1` tool contracts
**And** outdated examples are removed
