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
- **Actor kinds are explicit**: `HumanActor`, `AgentActor`. Authority-bearing
  actions (managing agents and customers, and later approving invoices) require a
  human.
- **Ownership is relational**: `relates_to_actor_via([:agent, :user])`. For
  creates, Ash checks the inserted row inside the transaction and rolls it back on
  failure, so it is not possible to create a record attached to someone else's
  agent.
- **Ownership is immutable** because no update action accepts `agent_id` or
  `user_id`.
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

Private keys, seed phrases, signing material and custody of funds. Wallet
accounts store **public** addresses and IBANs only. Signing belongs to a custody
system such as [Arktos](https://github.com/cognokratos/arktos-wallet), behind an
explicit adapter boundary (see [ROADMAP.md](ROADMAP.md)).

## Known gaps

These are deliberate scope limits of the current state, each tracked in the
roadmap:

1. **Open registration, no roles.** Anyone can register, and every user is an
   isolated "admin" of their own agents. Organizations, invitations and roles
   (e.g. *approver* vs *operator*) are planned (Epic 3) before approvals exist.
2. **No field encryption at rest.** Customer name and email are plaintext.
   AshCloak is planned for PII (Epic 7).
3. **No audit trail of domain actions yet** (Epic 5).
4. **No rate limiting** on sign-in or API routes. Use a reverse proxy in any
   real deployment.
5. **API key expiry is fixed at 365 days**, and there is no "last used" tracking.
   Humans also have no API sign-out endpoint yet.
6. **Agent id existence oracle.** `POST /customers` returns 403 for an agent id
   owned by someone else, but 400 ("does not exist") for an unknown id. That
   reveals whether an id exists. Random UUIDv4 ids make this impractical to
   exploit; a uniform error is planned with the Epic 3 roles work.
7. **Mail sender and host configuration** must be set for production
   (`MAIL_FROM`, `PHX_HOST`, an SMTP adapter); the default is the local mailbox.

## Reporting

Please report vulnerabilities privately through GitHub security advisories on
this repository rather than in a public issue.
