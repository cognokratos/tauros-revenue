# Lesson 2 · Ash policies and ownership

*Part I: Identity and ownership* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 3](03-tenant-isolation.md)

## Goal

See that authorization lives in the domain, once, and holds for every
interface: UI, REST, MCP and direct calls.

## Concept

A resource declares its actions and, next to them, who may run them.
Ownership is a *relationship path*: a customer belongs to an agent, which
belongs to a human. `relates_to_actor_via([:agent, :user])` lets a human reach
the customers of their own agents; `relates_to_actor_via(:agent)` lets an agent
reach only its own. Records you cannot see behave as if they did not exist
(404, not 403).

## Code to inspect

- `lib/tauros/revenue/customer.ex`: the whole `policies` block, three policies, each naming its actor kind
- `lib/tauros/revenue/customer.ex`, `update`: `accept [:name, :email]`. Moving a customer to another agent cannot even be expressed.
- `lib/tauros/revenue.ex`: the code interface (`list_customers`) and the JSON:API routes call the same actions

## Run it

```bash
mix test test/tauros/revenue/customer_test.exs
```

```elixir
Tauros.Revenue.list_customers!(actor: human)   # the human's agents' customers
Tauros.Revenue.list_customers!(actor: agent)   # only this agent's
```

## Break it

```elixir
Tauros.Revenue.create_customer(%{name: "X", email: "x@x.x", agent_id: agent.id}, actor: agent)
Tauros.Revenue.update_customer(customer, %{agent_id: other_agent.id}, actor: human)
```

## Why it fails

The first is refused by `forbid_unless HumanActor` on customer writes: an agent
may read customers but never manage them, not even its own. The second is
invalid input: `update` does not accept `agent_id`, so there is nothing to
authorize.

## What to remember

- One policy, written once, covers every interface.
- "Make the wrong thing impossible to express" (accept lists) beats checking it.
- Invisible means non-existent: no information leaks through a 403.

**Next:** [Lesson 3 · Tenant isolation](03-tenant-isolation.md)
