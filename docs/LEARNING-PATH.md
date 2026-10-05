# Learning path

A reading order through the repository. Each stop names one idea and the
smallest piece of code that demonstrates it. A full, exercise-based curriculum
will build on this.

## 1. The problem: capability vs authority

Read [VISION.md](VISION.md), then [AI-AUTHORITY.md](AI-AUTHORITY.md). Keep one
question in mind for the rest of the path: *what stops an agent with a valid key
from doing this?*

## 2. A domain is a list of declarations

Open `lib/tauros/revenue/customer.ex`. Everything about a customer is in one
module: shape, actions, who may call them, and validation. Then open
`lib/tauros/revenue.ex` and see how the domain picks the public surface: the code
interface (`list_customers`) and the HTTP routes (`base_route "/customers"`).

*Try:* in `iex -S mix`, call `Tauros.Revenue.list_customers!(actor: user)` with two
different users.

## 3. Policies are the only gate

Read the `policies` block in `customer.ex`, then
`lib/tauros/accounts/checks/human_actor.ex`. One policy covers every action:
"the actor must be a human, and the customer's agent must belong to them".

*Try:* `test/tauros/revenue/customer_test.exs`. Find the test showing that an
agent can't create a customer *even for itself*, and explain which line of the
policy causes it.

## 4. Make the wrong thing impossible to express

In `customer.ex`, `update` accepts only `[:name, :email]`. There is no code
that checks for "ownership reassignment", because the action has no way to
express it. Compare `wallet_account.ex`, which has no update action at all.

## 5. Identity for non-humans

`lib/tauros/accounts/agent.ex` uses the AshAuthentication `api_key` strategy.
`lib/tauros/accounts/agent/changes/issue_api_key.ex` issues a key inside the
create transaction and returns it once, as metadata. Then read
`lib/tauros_web/api_auth.ex` to see how one bearer header becomes either a human
or an agent actor.

## 6. One domain, many interfaces

Follow "register a wallet account" through `POST /api/v1/wallet-accounts`
([API.md](API.md)), the generated LiveView in `lib/tauros_web/live/wallet_account_live/`,
and the domain test. All three call `Tauros.Revenue.create_wallet_account`.
AI tools (Epic 4) will be the fourth caller, with nothing new below them.

## 7. Where this is heading

Read the concepts in the order they will be implemented:

1. [Intent, authority, execution](concepts/intent-authority-execution.md)
2. [Financial state machines](concepts/financial-state-machines.md)
3. [Idempotency](concepts/idempotency.md)
4. [Auditability](concepts/auditability.md)
5. [Eventual consistency and reconciliation](concepts/eventual-consistency.md)

Then see [ROADMAP.md](ROADMAP.md) for which epic turns each one into code.
