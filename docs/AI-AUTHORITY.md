# AI capability is not financial authority

Tauros exists to teach one principle:

> An AI agent may be very **capable** (it can read, search, draft and propose),
> but capability never confers **authority** to move money or change financial
> commitments. Authority is held by humans and enforced by deterministic code.

This page explains how the application is built so that the principle is a
property of the system and not a line in a prompt.

## Build the domain first, then expose it

```text
Human UI ──────────┐
                   │
REST API ──────────┼──→  Ash actions ──→ policies ──→ state machine ──→ database
                   │
AshAI / MCP ───────┘
```

AI tools in Tauros will be **the same Ash actions** the UI and the API call,
exposed through [AshAI](https://hexdocs.pm/ash_ai). There is no separate "AI
backend", no second copy of business logic and no handwritten MCP server. (The
Rust projects in CognoKratos already teach MCP from the wire up; Tauros teaches
what to put behind it.)

Consequences:

- A policy written once (for example "agents only see their own customers")
  holds for an LLM tool call just as it does for a REST request.
- A tool can never do more than the action it wraps. If the action is missing,
  the AI cannot do it, however it is prompted.
- Tool descriptions come from action descriptions and argument types, so the
  model sees the same contract that the code enforces.

## Exposure is an explicit allowlist

> The existence of an Ash action does not mean that action should be exposed
> through AshAI.

AshAI tools are declared one by one in the domain (`tools do tool :name,
Resource, :action end`). Tauros will keep that list short and reviewable. The
planned capability matrix:

| Action | Human (UI) | Service / API key | AI tool |
| --- | --- | --- | --- |
| list customers, wallet accounts, invoices | ✅ | ✅ | ✅ read-only |
| create invoice draft | ✅ | ✅ | ✅ |
| edit draft | ✅ | ✅ | ✅ |
| submit for approval | ✅ | ✅ | ✅ |
| **approve / reject invoice** | ✅ | ❌ | ❌ |
| **issue invoice** | ✅ | restricted (job after approval) | ❌ |
| record payment, reconcile payment | ✅ | ✅ (settlement services) | ❌ |
| register agent, rotate API key | ✅ | ❌ | ❌ |

Two independent layers enforce the bold rows:

1. **Not exposed.** The tool is not in the AshAI allowlist.
2. **Not permitted.** Even if it were exposed, or the same agent called the REST
   route directly, the policy `authorize_if HumanActor` on `approve` would refuse
   it. The allowlist limits what the model is *offered*; policies limit what
   any agent can *do*.

## Who the AI acts as

An AI client authenticates as an **agent**, with the agent's API key. It acts with
that agent's permissions, and never with those of the human who owns the agent.
This already works today: an agent can register wallet accounts and read its
own, and every authority-bearing action checks `HumanActor`.

| Today (implemented) | Agent | Human |
| --- | --- | --- |
| Register / rename / delete agents, rotate keys | ❌ | ✅ owner |
| Create / edit / delete customers | ❌ | ✅ owner |
| Register wallet accounts | ✅ its own | ❌ |
| Read wallet accounts | ✅ its own | ✅ all of their agents' |

Wallet registration being agent-only is deliberate: the agent proposes where it
will be paid, the record is immutable, and the human sees every destination in
the UI. Approving which destination an invoice may use will be a human decision
(Epic 3).

## What the model may and may not do

| May (capability) | May not (authority) |
| --- | --- |
| interpret a request, search records, summarize history | approve, reject, issue or cancel a financial document |
| prepare and submit an invoice draft with its reasoning | set or change any `state` |
| propose a reconciliation match | mark anything as paid |
| explain why a policy refused an action | change who owns a record |
| retry safely (with idempotency keys) | hold or use keys; sign anything |

## Why not enforce this in the prompt?

Prompts are inputs to a probabilistic component. A guardrail in a prompt is a
suggestion the model may ignore, misread or be talked out of by injected
content. Policies, state machines and allowlists are evaluated by the BEAM on
every call, whatever the conversation says. The
[`simple-agent-template`](https://github.com/cognokratos/simple-agent-template)
calls the model an *untrusted decision maker*; Tauros applies that idea to money.
