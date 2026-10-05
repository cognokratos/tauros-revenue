# Architecture

Tauros is a Phoenix application whose business logic lives entirely in
[Ash](https://ash-hq.org) resources. Every interface (LiveView UI, JSON:API and,
later, AI tools) calls the same Ash actions. Those actions go through the same
policies, validations and changes, and there is no other path to the database.

```text
 Human browser            Services / agents            AI clients (planned)
      │                          │                            │
 LiveView + AshPhoenix     AshJsonApi (/api/v1)        AshAI MCP (allowlist)
      │                          │                            │
      └──────────────┬───────────┴────────────────────────────┘
                     ▼
        Ash domains: Tauros.Accounts · Tauros.Revenue
          actions · policies · validations · changes
                     │
                AshPostgres ──▶ PostgreSQL
```

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

## Domains

Domains are drawn around *reasons to change*, not around tables.

- **`Tauros.Accounts`: who may act.** `User` is the human, `Agent` the AI or service
  principal, and `Token` and `ApiKey` are their credentials. Authentication is
  configured here and nowhere else.
- **`Tauros.Revenue`: the financial core.** `Customer` is who is billed and
  `WalletAccount` is where money is received. Invoices, approvals, payments and
  reconciliation will join this domain (see [ROADMAP.md](ROADMAP.md)), because
  they share its invariants: an invoice is billed to a customer of the same agent
  and is paid into one of that agent's wallet accounts.

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
| Business validation | `validations` with `where:` | address format per settlement rail |
| Side effects inside the transaction | `Ash.Resource.Change` | `IssueApiKey` issues or rotates a key |
| Referential integrity | `postgres references` | agents with customers cannot be deleted |

A rule never lives only in a LiveView or a controller. LiveViews pass the actor
and render what Ash returns. The JSON:API is generated from the domain routes.

## Authentication

**Humans in the browser** use the generated AshAuthenticationPhoenix pages:
`/sign-in`, `/register`, `/reset` and magic links. The session is restored by
`load_from_session`. Authenticated LiveViews sit in one
`ash_authentication_live_session` whose `on_mount` is
`{TaurosWeb.LiveUserAuth, :live_user_required}`.

**API clients** send one header, `Authorization: Bearer <credential>`:

1. `load_from_bearer` (AshAuthentication) resolves a human's sign-in token.
2. `AshAuthentication.Strategy.ApiKey.Plug` resolves an agent API key. Its
   `on_error` ignores credentials that are not API keys, such as a human token.
3. `TaurosWeb.ApiAuth.require_actor/2` returns `401` if neither resolved. The
   only exceptions are the sign-in route and the OpenAPI document.

Whichever credential resolves becomes the Ash actor. From then on,
**authorization is entirely Ash policies**.

## Handwritten code

The rewrite tries to make generated code do the work. This is everything that
is not generator output or a configuration line:

| Module | Lines | Why it exists |
| --- | --- | --- |
| `Accounts.Agent` actions/policies, `Revenue.Customer`, `Revenue.WalletAccount` | ~170 of DSL | the actual business rules |
| `Accounts.Checks.HumanActor`, `AgentActor` | 20 | lets policies say which kind of actor they mean |
| `Accounts.Agent.Changes.IssueApiKey` | 31 | issue or rotate a key and return the plaintext once |
| `Revenue.Currency` | 35 | currencies grouped by settlement rail |
| `TaurosWeb.ApiAuth` | 46 | one bearer header for both actor kinds; 401 without credentials |
| `AuthenticationFailed` → JSON:API error | 14 | failed sign-in is a 401, not a 403 |
| `DashboardLive` | 76 | the landing page |
| Edits to generated LiveViews | small | show API keys once, agent selector, agent names, empty states |

The old Ecto implementation had about 4,800 lines in `lib/` and 3,400 in `test/`.
The rewrite has about 3,200 and 1,100. Most of the 3,200 are generated
components and authentication resources.

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
mix ash.gen.resource Tauros.Revenue.WalletAccount ...
mix ash.gen.change Tauros.Accounts.Agent.Changes.IssueApiKey
mix ash.extend Tauros.Accounts.User json_api
mix ash_phoenix.gen.live --domain ... --resource ...   # agents, customers, wallet accounts
mix ash.codegen initial_schema                          # the only migration
mix credo gen.config
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
  above). The generated wallet-account form was deleted because humans don't
  register wallet accounts.
- **Layout:** the generated Phoenix marketing header was replaced with the app
  navigation. The root layout got Tauros branding and a Content-Security-Policy.
- **Senders:** the generated `from` placeholders now read `config :tauros, :mail_sender`.

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
4. **Out-of-scope reads are 404, out-of-scope writes are 403.** This matches the
   intent of story 1.4: reading a record you can't see behaves like it doesn't
   exist. Creating a customer for someone else's agent is a policy denial (403);
   the old API reported a 422.
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
   agents, customers and wallet accounts through policies.
9. **Dropped: the `/test` endpoints, the account-settings page and the unused
   PubSub subscription.** The test endpoints only existed to smoke-test auth.
   Password changes go through the generated reset flow. Nothing ever broadcast on
   the PubSub topic.
10. **Extensions are added only when used.** AshAI, AshStateMachine, AshOban,
    AshPaperTrail, AshMoney and AshCloak are planned for specific epics in
    [ROADMAP.md](ROADMAP.md) and are not installed yet.
