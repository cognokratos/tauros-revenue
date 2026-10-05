# Source this file (`source docs/examples/mcp_env.sh`) to get an MCP session by hand.
# Needs a running app with the demo seeds (`mix setup && mix phx.server`), curl and jq.
#
# It signs in as the demo approver over REST, creates a fresh agent (its API key
# is shown once), gives it a customer, lets the agent register a USDC-on-Base
# destination, and defines:
#
#   mcp <credential> <method> <params-json>   one MCP JSON-RPC request (protocol 2026-07-28)
#   call <tool> <arguments-json>              tools/call as the new agent ($KEY)
#   out                                       print a tool result or error compactly
#
# Every credential comes from the REST API; nothing bypasses authorization.

BASE=${BASE:-localhost:4000}
J='content-type: application/vnd.api+json'

TOKEN=$(curl -s -X POST $BASE/api/v1/users/sign-in -H "$J" \
  -d '{"data":{"attributes":{"email":"demo@tauros.local","password":"tauros-demo-password"}}}' | jq -r .meta.token)
CREATED=$(curl -s -X POST $BASE/api/v1/agents -H "authorization: Bearer $TOKEN" -H "$J" \
  -d '{"data":{"type":"agent","attributes":{"name":"MCP agent '$RANDOM'"}}}')
KEY=$(echo "$CREATED" | jq -r .meta.api_key)
AGENT_ID=$(echo "$CREATED" | jq -r .data.id)
curl -s -X POST $BASE/api/v1/customers -H "authorization: Bearer $TOKEN" -H "$J" \
  -d '{"data":{"type":"customer","attributes":{"name":"Initech","email":"ap@initech.example","agent_id":"'$AGENT_ID'"}}}' >/dev/null
curl -s -X POST $BASE/api/v1/payment-destinations -H "authorization: Bearer $KEY" -H "$J" \
  -d '{"data":{"type":"payment_destination","attributes":{"label":"Treasury (Base)","currency":"USDC","network":"base","address":"0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"}}}' >/dev/null

mcp() {
  local cred=$1 method=$2 params=$3 name
  name=$(echo "$params" | jq -r '.name // empty')
  curl -s -X POST $BASE/mcp \
    ${cred:+-H "authorization: Bearer $cred"} \
    -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
    -H 'mcp-protocol-version: 2026-07-28' -H "mcp-method: $method" ${name:+-H "mcp-name: $name"} \
    -d "$(jq -n --arg m "$method" --argjson p "$params" '{jsonrpc:"2.0",id:1,method:$m,
          params:($p + {_meta:{"io.modelcontextprotocol/protocolVersion":"2026-07-28",
            "io.modelcontextprotocol/clientInfo":{name:"curl",version:"1"},
            "io.modelcontextprotocol/clientCapabilities":{}}})}')"
}
call() { mcp "$KEY" tools/call "$(jq -n --arg n "$1" --argjson a "$2" '{name:$n,arguments:$a}')"; }
out() { jq -c '.result.structuredContent // (.result.content[0].text | (fromjson? // .)) // .error'; }

echo "Agent key in \$KEY, human token in \$TOKEN. Try: mcp \"\$KEY\" tools/list '{}' | jq '[.result.tools[].name]'"
