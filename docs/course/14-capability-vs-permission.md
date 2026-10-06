# Lesson 14 · AI capability vs actor permission

*Part IV: AI capability* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 15](15-prompt-injection.md)

## Goal

Separate two questions that are easy to conflate: what an agent **may** do,
and what a model is **offered**.

## Concept

| | Decided by | Example |
| --- | --- | --- |
| Actor permission | Ash policies | an agent may deactivate its own destination |
| AI exposure | a review (`mcp_tools/0`) | that action is not an MCP tool |

Every tool must be permitted (invariant A), but not every permitted action is
a tool (invariant B). Authority actions are refused twice: no tool exists
(layer 1, capability surface), and the policy refuses the agent anyway
(layer 2, authorization). See the matrix in
[AI-AUTHORITY.md](../AI-AUTHORITY.md#actor-permission-vs-ai-exposure).

## Code to inspect

- `lib/tauros/authority.ex`: `agent_safe/0` vs `mcp_tools/0`
- `test/tauros_web/mcp/attacks_test.exs`: "authority tools do not exist (layer 1), and the actions refuse the agent (layer 2)"

## Run it

```bash
mix test test/tauros_web/mcp/attacks_test.exs
```

## Break it

With the same agent key (`source docs/examples/mcp_env.sh`), deactivate a
destination over REST, where the policy permits it, then look for that
capability over MCP:

```bash
DEST=$(curl -s localhost:4000/api/v1/payment-destinations -H "authorization: Bearer $KEY" | jq -r '.data[0].id')
curl -s -X PATCH localhost:4000/api/v1/payment-destinations/$DEST/deactivate -H "authorization: Bearer $KEY" \
  -H 'content-type: application/vnd.api+json' -d '{"data":{"type":"payment_destination","id":"'$DEST'","attributes":{}}}' \
  | jq '.data.attributes.state'                                # "deactivated": permitted
mcp "$KEY" tools/list '{}' | jq '[.result.tools[].name]'       # no deactivate tool: not offered
```

Then call `approve_invoice` over MCP and the approve route over REST
([Exercise 9](../EXERCISES.md#9-try-to-approve)).

## Why it fails

REST offers the agent everything its policies allow; MCP offers a reviewed
subset. `approve_invoice` is "Tool not found" (layer 1) and the REST route is
403 (layer 2, the `HumanApprover` policy).

## What to remember

- Permission is a policy; exposure is a product decision; keep both explicit.
- Which layer is capability, and which is authority? Be able to point at each.
- Never let exposure be the only thing between a model and authority.

**Next:** [Lesson 15 · Prompt injection vs deterministic authority](15-prompt-injection.md)
