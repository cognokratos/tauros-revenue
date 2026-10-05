# Security

Tauros is an **educational blueprint**, not an audited financial product. This
page states what it protects, how, and where the known gaps are.

## Principals and credentials

| Principal | Credential | Storage | Lifetime |
| --- | --- | --- | --- |
| Human (browser) | session cookie holding an AshAuthentication token | token stored in `tokens` (`store_all_tokens? true`); presence required for authentication | until sign-out; "log out everywhere" on password change |
| Human (API) | bearer JWT from `POST /api/v1/users/sign-in` | same token store; presence required | until expiry, or "log out everywhere" on password reset (there is no API sign-out endpoint yet) |
| Agent | API key `tauros_…` | SHA-256 hash in `api_keys`; plaintext shown once | 365 days, or until rotated |
| Password | — | Argon2id (`AshAuthentication.Argon2Provider`) | — |

There is one HTTP authentication header for both principal kinds:
`Authorization: Bearer`. The generated AshAuthentication plugs try to resolve the
credential (`get_by_subject` for a token, `sign_in_with_api_key` for a key). If
neither succeeds, `TaurosWeb.ApiAuth` returns `401` before any business action
runs. The only routes reachable without a credential are `POST /api/v1/users/sign-in`
and the OpenAPI document.

Key rotation locks the agent row (`get_and_lock_for_update`), so concurrent
rotations cannot leave two valid keys behind.

## Authorization model

- **Every action is authorized by Ash policies.** Domain code interfaces and
  AshPhoenix forms receive `actor:`, and nothing in the web layer calls the data
  layer directly.
- **Actor kinds are explicit**: `HumanActor`, `HumanApprover`, `AgentActor`.
  Authority-bearing actions (approving, rejecting, sending back and cancelling
  invoices; inviting humans) require a human approver; managing agents and
  customers requires a human. `Tauros.Authority` lists every business action as
  agent-safe, human-only or internal, and `test/tauros/authority_test.exs`
  checks the policies against it.
- **Registration is closed.** No strategy registers anyone. The first approver
  is designated with `bootstrap_approver` (allowed only while no approver
  exists, and never for an agent); everyone else is invited by an approver.
  Roles cannot be changed by any update action.
- **Defence in depth for approvals.** An `Approval` can only be created through
  an Invoice decision action *and* only for a human approver who owns the
  agent: two independent policies.
- **Ownership is relational**: `relates_to_actor_via([:agent, :user])`. For
  creates, Ash checks the inserted row inside the transaction and rolls it back on
  failure, so it is not possible to create a record attached to someone else's
  agent.
- **Ownership is immutable** because no update action accepts `agent_id` or
  `user_id`.
- **Foreign ids are never trusted.** An invoice revision loads the customer and
  destination it names and compares their `agent_id` with the invoice's. An
  unknown id and another agent's id get the same error.
- **Financial content is immutable.** Invoice revisions, approvals and audit
  events have no update or destroy action. Each revision's payload is sealed
  with SHA-256; approval re-seals it and refuses a revision altered behind the
  application's back.
- **Transitions run under a row lock** and are checked against the current
  state, so concurrent or stale requests cannot both succeed. Unique indexes
  (one decision per revision; one invoice per agent and idempotency key) are
  the backstop.
- **Invisible is the same as non-existent**: reading, updating or deleting another
  human's record returns 404, not 403.
- **Generated credentials are unreadable**: `ApiKey` has no read policy except
  AshAuthentication's own sign-in interaction.

The tests in `test/tauros/**` assert these rules directly against the actions, in
addition to the UI and API tests.

## Web hardening

- Phoenix CSRF protection and secure browser headers on the browser pipeline.
- **Content-Security-Policy**: `default-src 'self'`, no framing, and the socket
  limited to `connect-src 'self'`. `'unsafe-inline'` scripts are allowed only
  because of the generated theme-switch snippet in `root.html.heex`.
- Sobelow runs in CI with `--exit`.
- Dependency advisories: `mix deps.audit` (mix_audit) and `mix hex.audit` run in CI.

## Data Tauros will never hold

Private keys, seed phrases, signing material and custody of funds. Payment
destinations store **public** addresses and IBANs only. Signing belongs to a custody
system such as [Arktos](https://github.com/cognokratos/arktos-wallet), behind an
explicit adapter boundary (see [ROADMAP.md](ROADMAP.md)).

## Known gaps

These are deliberate scope limits of the current state, each tracked in the
roadmap:

1. **No organizations.** Humans are isolated: an approver decides on invoices
   of the agents they own. There is no sharing of agents between humans, and
   no separation of duties between two people (the human who owns an agent can
   approve its proposals). `bootstrap_approver` is meant to be run once from a
   console; two simultaneous runs on an empty installation could create two
   approvers.
2. **No field encryption at rest.** Customer name and email are plaintext.
   AshCloak is planned for PII (Epic 7).
3. **The audit trail is a lightweight envelope** (`InvoiceEvent`), enforced
   append-only by the application, not yet by the database (Epic 5).
   Destination lifecycle and agent management are not yet recorded as events.
4. **No rate limiting** on sign-in or API routes. Use a reverse proxy in any
   real deployment.
5. **API key expiry is fixed at 365 days**, and there is no "last used" tracking.
   Humans also have no API sign-out endpoint yet.
6. **Agent id existence oracle.** `POST /customers` returns 403 for an agent id
   owned by someone else, but 400 ("does not exist") for an unknown id. That
   reveals whether an id exists. Random UUIDv4 ids make this impractical to
   exploit. Invoices do not have this problem: unknown and foreign customers and
   destinations get the same error. Customers will get a uniform error too.
7. **EVM addresses are format-checked only.** The EIP-55 checksum is not
   verified (OTP has no Keccak-256). A mistyped lowercase EVM address passes.
   Destinations are shown to humans before any invoice using them is approved.
8. **A token symbol is not a contract.** "USDC on Arbitrum" does not say
   which contract; execution (Epic 6) must map it before watching for payments.
9. **Mail sender and host configuration** must be set for production
   (`MAIL_FROM`, `PHX_HOST`, an SMTP adapter); the default is the local mailbox.

## Reporting

Please report vulnerabilities privately through GitHub security advisories on
this repository rather than in a public issue.
