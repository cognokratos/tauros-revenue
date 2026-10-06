# Lesson 12 · AshAI and MCP

*Part IV: AI capability* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 13](13-reviewed-tool-surface.md)

**Before this lesson:** Part III. You should be able to say which policy stops
an agent from approving, before giving an AI a way in.

## Goal

Expose the domain to AI clients without writing a second backend: the same
actions, the same policies, an agent as the actor.

## Concept

AshAI generates MCP tools from Ash actions. Tauros serves them at `/mcp` to
**agents only**: the `:mcp` pipeline accepts an agent API key and nothing else
(a human's bearer token gets 401). Every tool call runs as that agent, under
the policies you studied in Parts I–III. Tauros runs no model: no ReqLLM, no
prompts, no agent loop. Reference: [MCP.md](../MCP.md).

## Code to inspect

- `lib/tauros_web/router.ex`: the `:mcp` pipeline and `forward "/", AshAi.Mcp.Router`
- `lib/tauros_web/api_auth.ex`: `require_agent/2`
- `lib/tauros/revenue.ex`: the `tools` block, eight tools on existing actions

## Run it

```bash
mix test test/tauros_web/mcp/authentication_test.exs
source docs/examples/mcp_env.sh   # with the app running
mcp "$KEY" tools/list '{}' | jq '[.result.tools[].name]'
mcp "$TOKEN" tools/list '{}'      # a human's token: 401
```

## Break it

Present another agent's MCP session id with your own key, or a human token:

```bash
mix test test/tauros_web/mcp/authentication_test.exs   # "a session id carries no identity…", "a human bearer token is refused…"
```

## Why it fails

`require_agent/2` refuses anything but an agent key, and AshAI keeps no
session state: the actor is read from the authenticated connection on every
request.

## What to remember

- An AI tool is just another interface onto the same actions.
- MCP callers are agents; humans keep the UI and REST.
- No authorization lives in the MCP layer.

**Next:** [Lesson 13 · Designing a reviewed tool surface](13-reviewed-tool-surface.md)
