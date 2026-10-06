# Lesson 1 · Humans and agents

*Part I: Identity and ownership* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 2](02-policies-and-ownership.md)

## Goal

Know exactly *who* can act in Tauros, how each kind of actor proves who it is,
and why "an agent with a valid key" is still not "someone with authority".

## Concept

Tauros has two kinds of actor, and every policy says which one it means:

| Actor | Struct | Authenticates with | Holds |
| --- | --- | --- | --- |
| Human operator | `%User{role: :operator}` | password / magic link, or a bearer token | manages agents and customers |
| Human approver | `%User{role: :approver}` | same | also **authority**: approve, reject, request changes, cancel, invite |
| Agent | `%Agent{}` | an API key, shown once, stored hashed | **capability** only |

Registration is closed: strangers cannot sign up and make themselves approvers.
The first approver is bootstrapped once; everyone else is invited.
Read [AI-AUTHORITY.md](../AI-AUTHORITY.md) for why this split is the whole point.

## Code to inspect

- `lib/tauros/accounts/checks/human_actor.ex`, `human_approver.ex`, `agent_actor.ex`: three tiny checks every policy uses
- `lib/tauros/accounts/user.ex`: `registration_enabled? false`, the `invite` and `bootstrap_approver` actions and their policies
- `lib/tauros/accounts/agent.ex` and `agent/changes/issue_api_key.ex`: a key issued inside the create transaction, returned once
- `lib/tauros_web/api_auth.ex`: one bearer header becomes either a human or an agent actor; `/mcp` accepts agents only

## Run it

```bash
mix test test/tauros/accounts/user_test.exs test/tauros/accounts/agent_test.exs
```

In the app (`mix setup && mix phx.server`, sign in as `demo@tauros.local`):
open **Agents**, create one, and notice the key is shown exactly once.

## Break it

```elixir
# iex -S mix, after the console setup in docs/EXERCISES.md
Tauros.Accounts.bootstrap_approver("ai@example.com", actor: agent)
Tauros.Accounts.invite_user("ai@example.com", :approver, actor: agent)
```

## Why it fails

`bootstrap_approver` says `forbid_if AgentActor`, then `authorize_if NoApproverYet`;
`invite` says `authorize_if HumanApprover`. An `%Agent{}` matches neither.
(`test/tauros/accounts/user_test.exs`, "is never available to an agent, even
before any approver exists".)

## What to remember

- Identity is a struct type, and every policy names the kind of actor it means.
- An API key proves *which agent* is calling, never that it may decide.
- No action accepts `role`; authority cannot be self-granted.

**Next:** [Lesson 2 · Ash policies and ownership](02-policies-and-ownership.md)
