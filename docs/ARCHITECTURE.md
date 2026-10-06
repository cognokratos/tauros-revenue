# Architecture

Tauros is a Phoenix application whose business logic lives entirely in
[Ash](https://ash-hq.org) resources. Every interface (LiveView UI, JSON:API and
AI tools over MCP) calls the same Ash actions. Those actions go through the
same policies, validations and changes, and there is no other path to the
database.

```text
 Human browser             REST clients                  AI clients
 (humans)                  (humans or agents)            (agents only)
      │                          │                            │
 LiveView + AshPhoenix     AshJsonApi /api/v1           AshAI MCP /mcp
 interface: :ui            interface: :api              interface: :mcp
      │                          │                      authenticated as an Agent;
      │                          │                      8 reviewed tools, no human
      │                          │                      authority action is a tool
      └──────────────┬───────────┴────────────────────────────┘
                     ▼
        Ash actions (Tauros.Accounts · Tauros.Revenue)
                     │
        Ash policies ─ who may (HumanApprover, AgentActor, ownership)
                     │
        state machines ─ which moves exist (checked under a row lock)
                     │
        validations · idempotency · immutable revisions
                     │
        AshPostgres ──▶ PostgreSQL
```

The interface is recorded for audit and never consulted for authorization.
MCP differs from REST only in offering a deliberately narrower set of actions.

## Stack

| Layer | Choice | Version |
| --- | --- | --- |
| Language/runtime | Elixir on OTP | 1.20 / 29 (pinned in `.tool-versions`) |
| Web | Phoenix, LiveView, Bandit | 1.8 / 1.2 |
| Domain | Ash | 3.34 |
| Persistence | AshPostgres on PostgreSQL | 2.14 / 17 |
| Authentication | AshAuthentication + AshAuthenticationPhoenix | 4.15 / 2.17 |
| UI integration | AshPhoenix (forms, LiveView generators) | 2.3 |
| REST | AshJsonApi (JSON:API + OpenAPI) | 1.7 |
| Lifecycles | AshStateMachine | 0.2 |
| AI tools (MCP) | AshAI, without ReqLLM or any model runtime | 1.1.1 |

## Domains

Domains are drawn around *reasons to change*, not around tables.

- **`Tauros.Accounts`: who may act.** `User` is the human, `Agent` the AI or service
  principal, and `Token` and `ApiKey` are their credentials. Authentication is
  configured here and nowhere else.
- **`Tauros.Revenue`: the financial core.** `Customer` is who is billed,
  `PaymentDestination` is where money is received, `Invoice` (with immutable
  `InvoiceRevision`s) is what is owed, `Approval` is a human decision, and
  `InvoiceEvent` is the audit envelope. They share invariants (an invoice bills a
  customer of the same agent and is paid into one of that agent's active
  destinations), which is why they are one domain. Payments and reconciliation
  will join it (see [ROADMAP.md](ROADMAP.md)).

Each domain declares its **code interface**, for example
`Tauros.Revenue.list_customers!(actor: user)` or
`Tauros.Accounts.create_agent!("Bot", actor: user)`. It also declares its **JSON:API
routes**. Resources hold everything else.

## Where the rules live

| Concern | Ash construct | Example |
| --- | --- | --- |
| Shape and constraints | attributes, `constraints` | `name` trimmed, ≤ 160 chars |
| Ownership assignment | `change relate_actor/1` | `agent_id` comes from the authenticated agent |
| Immutable fields | action `accept` lists | customer `update` does not accept `agent_id` |
| Who may do what | `policies` | `relates_to_actor_via([:agent, :user])` |
| Business validation | `validations` (custom modules where needed) | address checksum per rail; customer and destination belong to the invoice's agent |
| Validation against the locked row | `validate …, before_action?: true` after the lock | submitting needs an undecided revision and an active destination |
| Lifecycle | `state_machine` (AshStateMachine) | `draft → pending_approval → approved` |
| Transition under concurrency | `Tauros.Revenue.Changes.Transition` | `SELECT … FOR UPDATE`, then ask the state machine about the current state |
| Records only another action may write | `manage_relationship` + `accessing_from` in the policy | revisions and approvals are created only by Invoice actions |
| Retry safety | a change that locks, looks up and uses `set_result` | `create_draft` replays; decisions replay |
| Side effects inside the transaction | `Ash.Resource.Change` | `IssueApiKey`; `RecordEvent` appends the audit envelope |
| Uniqueness that must hold under races | `identities` (unique indexes) | one decision per revision; one invoice per agent and key |
| Referential integrity | `postgres references` | agents with invoices cannot be deleted |

A rule never lives only in a LiveView or a controller. LiveViews pass the actor
and render what Ash returns. The JSON:API is generated from the domain routes.

## Authentication

**Humans in the browser** use the generated AshAuthenticationPhoenix pages:
`/sign-in`, `/reset` and magic links. Registration is closed (both strategies
have `registration_enabled? false`); humans are invited by an approver. The session is restored by
`load_from_session`. Authenticated LiveViews sit in one
`ash_authentication_live_session` whose `on_mount` is
`{TaurosWeb.LiveUserAuth, :live_user_required}`.

**MCP clients** (`/mcp`) are agents only. The `:mcp` pipeline runs the
AshAuthentication `api_key` plug for `Agent` and `TaurosWeb.ApiAuth.require_agent/2`,
which answers 401 unless an agent was resolved. There is no `load_from_bearer`
there, so a human's token never authenticates. The pipeline records
`interface: :mcp`, and `AshAi.Mcp.Router` runs every tool as that agent.

**API clients** send one header, `Authorization: Bearer <credential>`:

1. `load_from_bearer` (AshAuthentication) resolves a human's sign-in token.
2. `AshAuthentication.Strategy.ApiKey.Plug` resolves an agent API key. Its
   `on_error` ignores credentials that are not API keys, such as a human token.
3. `TaurosWeb.ApiAuth.require_actor/2` returns `401` if neither resolved. The
   only exceptions are the sign-in route and the OpenAPI document.

Whichever credential resolves becomes the Ash actor, and the pipeline records
`interface: :api` in the Ash context for the audit envelope. From then on,
**authorization is entirely Ash policies**; the interface is never consulted.

## Handwritten code

The rewrite tries to make generated code do the work. This is everything that
is not generator output or a configuration line:

| Module | Lines | Why it exists |
| --- | --- | --- |
| `Accounts.Agent`, `Accounts.User` (roles, invite, bootstrap) and `Revenue.*` resources | the DSL | the actual business rules, policies and state machines |
| `Accounts.Checks.*` | 55 | `HumanActor`, `HumanApprover`, `AgentActor`, `NoApproverYet` |
| `Revenue.Currency`, `Network`, `Address` | 255 | currency decimals; which network carries what; checksums per rail |
| `Revenue.FinancialPayload` | 105 | the canonical payload, its hash, exact arithmetic |
| `Revenue.Changes.Transition` | 65 | lock the row, then ask the state machine |
| `Invoice.Changes.ProposeRevision`, `Decide`, `RecordEvent` | 370 | idempotent proposals, exact-payload decisions, the audit envelope |
| Revision, destination, approval validations | 255 | cross-resource invariants that need a lookup |
| `Revenue.Errors.Conflict` | 40 | 409 errors with a machine-readable code |
| `Tauros.Authority` | 90 | the reviewed agent-safe / human-only list |
| `TaurosWeb.ApiAuth` | 55 | one bearer header for both actor kinds; 401 without credentials; interface context |
| `ApprovalLive`, `InvoiceLive.*`, `InvoiceComponents`, `InviteLive` | 745 | the approval inbox, invoice pages, invitations |
| `tools` block in `Tauros.Revenue` | ~130 of DSL | the eight MCP tools: action, output fields, model-facing description |
| `TaurosWeb.Mcp.StrictArguments` | 60 | refuse unknown top-level tool arguments and JSON floats (amounts are decimal strings) |
| `ApiAuth.require_agent`, `:mcp` pipeline | 35 | MCP callers are agents |
| `DashboardLive`, edits to generated LiveViews | small | landing page, destination state and lineage, agent names, empty states |

## Generators used

```bash
mix igniter.new tauros --with phx.new --with-args="--binary-id" \
  --install ash,ash_postgres,ash_phoenix,ash_json_api,ash_authentication,ash_authentication_phoenix \
  --auth-strategy magic_link
mix ash_authentication.add_strategy password --hash-provider argon2
mix ash.gen.resource Tauros.Accounts.Agent ...
mix ash_authentication.add_strategy api_key --user Tauros.Accounts.Agent --api-key Tauros.Accounts.ApiKey
mix ash.gen.resource Tauros.Revenue.Customer ...
mix ash.gen.enum Tauros.Revenue.Currency BTC,ETH,...
mix ash.gen.resource Tauros.Revenue.WalletAccount ...       # renamed PaymentDestination later
mix ash.gen.change Tauros.Accounts.Agent.Changes.IssueApiKey
mix ash.extend Tauros.Accounts.User json_api
mix ash_phoenix.gen.live --domain ... --resource ...   # agents, customers, wallet accounts
mix ash.codegen initial_schema
mix credo gen.config

# learning phase
mix ash.gen.enum Tauros.Revenue.Network bitcoin,ethereum,arbitrum,base,iban
mix igniter.install ash_state_machine
mix ash.gen.enum Tauros.Accounts.Role operator,approver
mix ash.gen.resource Tauros.Revenue.Invoice … Tauros.Revenue.InvoiceRevision … Tauros.Revenue.Approval … Tauros.Revenue.InvoiceEvent …
mix ash.gen.change … / mix ash.gen.validation …          # every custom change and validation
mix ash.codegen <name>                                   # one migration per step
```

The full arguments are in [DEVELOPMENT.md](DEVELOPMENT.md#generators). Generated
code needed manual edits in the following places:

- **Agent resource:** the `api_key` strategy generator assumes the subject is a
  "user". It doesn't add the `AshAuthentication` extension to a resource that
  lacks it, so that was added by hand. It also names the key's owner
  `belongs_to :user`, which was renamed to `:agent` so that `has_many
  :valid_api_keys` can infer `agent_id`.
- **API pipeline:** the generated `ApiKey.Plug` was given an `on_error` and
  followed by `require_actor` (see above). The JSON:API was moved from
  `/api/json` to `/api/v1`.
- **LiveViews:** headings, columns and a few product behaviours (see the table
  above). The generated wallet-account (now destination) form was deleted because humans don't
  register wallet accounts.
- **Layout:** the generated Phoenix marketing header was replaced with the app
  navigation, which collapses into a menu button below the `md` breakpoint. The
  root layout got Tauros branding and a Content-Security-Policy.
- **Core components:** `header` stacks its actions on small screens, `table` scrolls
  inside its own container and takes an optional per-column `class` (used to hide
  secondary columns on phones), and `list` wraps long values such as UUIDs and
  addresses.
- **Agent tokens:** `Agent` declares the shared `Token` resource with tokens disabled.
  AshAuthentication's sign-out helpers look up a token resource for every
  authenticated resource, so without it signing out crashed.
- **Senders:** the generated `from` placeholders now read `config :tauros, :mail_sender`.
- **Test config:** the auth installer configured fast `bcrypt_elixir` rounds for
  tests, but `add_strategy password --hash-provider argon2` didn't do the same
  for Argon2. `config/test.exs` now sets cheap Argon2 parameters instead.
- **User resource:** the generated `change_password` action had no policy and so
  could never be authorized. It now allows a user to change only their own
  password.
- **Closed registration:** the generated `register_with_password` action and the
  magic-link *create* (upsert) action were removed; magic-link sign-in is now the
  read action AshAuthentication expects when registration is disabled, and the
  router no longer passes `register_path`.
- **Migration `rename_wallet_accounts_to_payment_destinations`:** ash_postgres
  generated the column renames inside an `alter table` block, which Ecto
  rejects ("cannot execute nested commands"). The two `rename` calls were moved
  out of the block. The data backfill between that migration and the next is
  the one hand-written migration (codegen produces schema, not data).
- **`InvoiceLine`** is hand-written: `mix ash.gen.resource` has no embedded data
  layer option.
- **AshAI installer:** `mix igniter.install ash_ai --no-req-llm` also added an
  `AshAi.Mcp.Dev` plug to the endpoint in dev. It was removed: it is an
  unauthenticated second MCP endpoint pinned to the obsolete `2024-11-05`
  protocol, which contradicts "MCP callers are agents".

## Decisions

Older documents and the previous implementation disagreed in places. These
decisions resolve those disagreements.

1. **Agent API keys are generated by Tauros and shown once.** The PRD and story
   1.2 required this. The old code instead had the admin type a key in and
   verified requests by bcrypt-checking *every* agent's hash, which is O(n) per
   request. AshAuthentication's `api_key` strategy gives prefixed keys, an
   indexed lookup, SHA-256 at rest and rotation.
2. **One bearer header for humans and agents.** The old API had
   `Authorization: Bearer` for admins and `X-API-KEY` for agents. Using the
   generated plugs unchanged means one header; the credential itself says which
   kind of actor it is. *This is an intentional contract change.*
3. **JSON:API instead of a bespoke envelope.** The old
   `{error: {code, message, details}}` envelope was applied inconsistently: three
   shapes for `details`, `{agent: …}` vs `{data: …}`, and default Phoenix 404
   bodies. AshJsonApi gives one documented format, an OpenAPI spec at
   `/api/v1/open_api` and Swagger UI at `/api/swaggerui`, with no controllers.
   See [API.md](API.md) for the old-to-new mapping.
4. **Records you can't see behave as if they don't exist.** Reading, updating or
   deleting another human's record returns 404, which matches the intent of story
   1.4. Creating a customer for someone else's agent is a policy denial (403); the
   old API reported a 422.
5. **Agent management is scoped too.** The old agent show, edit and delete screens
   loaded agents without checking ownership. Ash policies make that class of bug
   impossible to write by accident.
6. **Unsupported currencies are rejected.** The old code accepted any currency and
   skipped address validation for unknown ones. Unvalidated payment destinations
   are not acceptable in a financial system.
7. **`wallet_accounts.agent_id` is a real foreign key** (it was a NOT NULL check
   misnamed `agent_fk`), and agents with dependents can't be deleted.
8. **The placeholder invoice counters were removed from the dashboard.** They
   showed zeros for a feature that does not exist. The dashboard now counts
   agents, customers and payment destinations through policies, and links to waiting proposals.
9. **Dropped: the `/test` endpoints, the account-settings page and the unused
   PubSub subscription.** The test endpoints only existed to smoke-test auth.
   Password changes go through the generated reset flow. Nothing ever broadcast on
   the PubSub topic.
10. **Extensions are added only when used.** AshStateMachine arrived with
    lifecycles and AshAI with the MCP tools (without ReqLLM: Tauros runs no
    model). AshOban, AshPaperTrail and AshCloak are planned for specific epics
    in [ROADMAP.md](ROADMAP.md) and are not installed yet.
11. **`WalletAccount` became `PaymentDestination`, with an explicit `network`.**
    The old model let the currency imply the rail, which is false for
    multi-network assets such as USDC and meaningless for IBANs. The rename cost
    one generated migration plus a backfill, and the API path changed (see
    [API.md](API.md#changes-in-the-learning-phase-breaking)). The name now says
    what the record is.
12. **Financial content lives in immutable revisions.** An approval names a
    revision and its SHA-256 payload hash. There is no "approved but edited"
    state to invalidate, because nothing financial is edited.
13. **Decimal, not AshMoney.** One explicit currency per invoice, per-currency
    decimal places, no implicit rounding, and an arithmetic context that traps
    rounding. ex_money's ISO 4217 model would add CLDR and still not describe
    network-specific tokens.
14. **Transitions are checked under a row lock**, because AshStateMachine's
    built-in change checks the caller's (possibly stale) copy.
15. **Revisions, approvals and events are written only by Invoice actions**:
    `manage_relationship` sets `accessing_from`, and their create policies
    require it. Events are written with `authorize?: false` inside an
    already-authorized action and have no create policy at all.
16. **Customers stay out of the payload hash** (only the id is hashed), so
    correcting a contact detail, or anonymizing it under GDPR (Epic 7), never
    invalidates an approval.
17. **AshAI is a thin exposure layer.** The tools are declared on existing
    actions; there is no handwritten MCP server, no second argument schema
    and no authorization in the MCP layer. It authenticates the agent, selects
    tools, shapes outputs, refuses unknown arguments and floats, and formats errors.
18. **MCP callers are agents** with their existing API key, through their own
    pipeline. Humans have the UI and REST.
19. **The MCP surface is an exact, reviewed list** (`Tauros.Authority.mcp_tools/0`),
    narrower than what an agent may do: deactivating a destination is
    permitted but not offered to a model.
20. **Model context is bounded on purpose.** `list_customers` returns no email
    and has no filter; `get_invoice` returns the current revision and its
    decision, not the full history or approver identities; write tools return
    the invoice's own fields.
