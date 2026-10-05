# Working on Tauros (for coding agents and contributors)

Tauros is a Phoenix 1.8 + Ash 3 application. Business rules live in Ash
resources; the web layer is thin. Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
and [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) before changing code.

## Commands

- `mix precommit` must pass before you finish (compile with warnings as errors, format, credo, sobelow, tests).
- `mix test test/path_test.exs` / `mix test --failed` while iterating.
- `mix ash.codegen <describe_change>` after any resource change. Never write migrations by hand.

## Generators first

If Phoenix, Ash, an Ash extension or Igniter can generate it, generate it, then
make the smallest edit needed. Check `mix help | grep -E "ash|igniter|phx"`
first. Typical generators: `ash.gen.resource`, `ash.gen.change`,
`ash.gen.validation`, `ash.gen.enum`, `ash.extend`,
`ash_authentication.add_strategy`, `ash_phoenix.gen.live` and
`igniter.install <pkg>`. Record new generator commands in docs/DEVELOPMENT.md.

## Domain rules

- Domains: `Tauros.Accounts` (User, Token, Agent, ApiKey) and `Tauros.Revenue`
  (Customer, WalletAccount, and later invoices and payments). Add resources to an
  existing domain unless the reason to change is genuinely different.
- Express rules declaratively, in this order of preference: attribute
  constraints and `accept` lists, then validations, changes, policies and
  calculations. Do not write context modules, service objects or repository
  wrappers around Ash.
- Every policy states which actor kind it means: `Tauros.Accounts.Checks.HumanActor`
  or `AgentActor`. Authority-bearing actions (approve, issue, cancel, manage
  agents) are human-only. **AI capability is not financial authority.**
- Ownership fields are set with `relate_actor/1` or accepted only on create.
  They are never updatable.
- No action may accept a lifecycle `state`. State changes are state-machine
  transitions (AshStateMachine).
- Financial commands must be idempotent and use Decimal or Money, never floats.
- Call actions through the domain code interface (`Tauros.Revenue.create_customer(attrs, actor: actor)`).
  Use `authorize?: false` only in fixtures, seeds, or changes running inside an
  already-authorized action.
- Tauros never stores private keys, seeds or signatures, only public addresses.

## Interfaces

- **LiveView:** use AshPhoenix forms (`AshPhoenix.Form.for_create/3` with
  `actor:`), streams for collections, and `<Layouts.app flash={@flash} current_user={@current_user}>`.
  The signed-in human is `@current_user` (AshAuthentication), not `@current_scope`.
  Authenticated LiveViews go in the existing `ash_authentication_live_session :authenticated_routes`.
- **REST:** add JSON:API routes in the domain's `json_api do routes ... end`.
  Do not write controllers for resources.
- **AI (planned, AshAI):** expose tools one by one in the domain. Never expose
  an authority-bearing action. Each tool needs a test in the allowlist test.

## Phoenix and HEEx conventions

- Use `<.input>`, `<.icon name="hero-…">` and the other core components;
  `<.flash_group>` only inside `layouts.ex`.
- HEEx: interpolate in attributes with `{...}`, use `<%= if/for/cond %>` blocks in
  bodies, give class lists as `[...]`, and use `<%!-- --%>` comments. Never write
  inline `<script>`; use colocated hooks (`:type={Phoenix.LiveView.ColocatedHook}`, names starting with `.`).
- Tailwind v4 with the generated daisyUI theme; no `@apply`.
- Use Req for HTTP clients.

## Tests

- Test actions and policies in `test/tauros/**`, including the actors who must be
  refused. Test interfaces in `test/tauros_web/**`.
- Build data with `Tauros.Fixtures`, which goes through the real actions.
- In LiveView tests, assert on element ids (`has_element?/3`), not raw HTML.
- Don't use `Process.sleep/1`. Use `start_supervised!/1` for processes.
