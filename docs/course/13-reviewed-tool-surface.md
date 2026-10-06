# Lesson 13 · Designing a reviewed tool surface

*Part IV: AI capability* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 14](14-capability-vs-permission.md)

## Goal

Design what a model is offered: an exact list, bounded outputs, strict inputs,
and money that never becomes a float.

## Concept

Eight tools: four reads, four proposals. The list is **exact** and reviewed
(`Tauros.Authority.mcp_tools/0`). Outputs are chosen (`select`/`load`): no
customer email, no approver identities, no full history. Inputs are strict:
unknown arguments are errors, at the top level and inside `input`, and JSON
numbers are refused because they arrive as IEEE floats. Amounts are decimal
strings.

## Code to inspect

- `lib/tauros/revenue.ex`, the `tools` block: descriptions say what each tool does *not* do
- `lib/tauros_web/mcp/strict_arguments.ex`: accepted names read from the published schema
- `test/tauros/mcp_tools_test.exs`: invariants A and B, and the schema contract

## Run it

```bash
mix test test/tauros/mcp_tools_test.exs test/tauros_web/mcp/strict_arguments_test.exs test/tauros_web/mcp/tools_test.exs
```

## Break it

Add a tool that is agent-safe but not reviewed, then run the allowlist test:

```elixir
# lib/tauros/revenue.ex, inside `tools do`
tool :deactivate_payment_destination, PaymentDestination, :deactivate
```

Also send `{"id": "…", "state": "approved"}` to `submit_invoice`, and an amount
as a number ([Exercise 10](../EXERCISES.md#10-replay-a-draft)).

## Why it fails

`McpToolsTest` compares the declared, routed and served tools with the
reviewed list for **equality**; inclusion in `agent_safe` is not enough.
`StrictArguments` answers "Unknown arguments for submit_invoice: state.
Accepted arguments: id" and refuses the float with its path. Remove the
tool afterwards.

## What to remember

- The tool list is a review, enforced by an equality test.
- Bound what a model sees; refuse what you did not declare.
- Money crosses JSON as strings.

**Next:** [Lesson 14 · AI capability vs actor permission](14-capability-vs-permission.md)
