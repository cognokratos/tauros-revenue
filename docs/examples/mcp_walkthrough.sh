#!/usr/bin/env bash
# The Tauros MCP walkthrough (docs/MCP.md): an AI client's whole journey, by hand.
# Needs a running app with the demo seeds (`mix setup && mix phx.server`), curl and jq.
# Every credential comes from the REST API; nothing bypasses authorization.
set -euo pipefail
source "$(dirname "$0")/mcp_env.sh" >/dev/null

echo "1. no credential:   $(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE/mcp -H 'content-type: application/json' -d '{}')"
echo "2. human token:     $(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE/mcp -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d '{}')"
echo "3. tools/list:      $(mcp "$KEY" tools/list '{}' | jq -c '[.result.tools[].name]')"
CUSTOMER=$(call list_customers '{}' | jq -r '.result.structuredContent.results[0].id')
echo "4. list_customers:  $(call list_customers '{}' | out)"
DEST=$(call list_payment_destinations '{}' | jq -r '.result.content[0].text | fromjson | .[0].id')
echo "5. destinations:    $(call list_payment_destinations '{}' | out)"
INPUT=$(jq -n --arg c "$CUSTOMER" --arg d "$DEST" '{input:{idempotency_key:"initech-2026-10",customer_id:$c,
  payment_destination_id:$d,currency:"USDC",due_date:"2099-01-31",
  lines:[{description:"Retainer",quantity:"1",unit_amount:"1200.00"}],reasoning:"Retainer per agreement."}}')
R=$(call create_invoice_draft "$INPUT"); INV=$(echo "$R" | jq -r .result.structuredContent.id)
echo "6. create draft:    $(echo "$R" | out)"
echo "7. replay draft:    $(call create_invoice_draft "$INPUT" | out)"
echo "8. conflict:        $(call create_invoice_draft "$(echo "$INPUT" | jq '.input.due_date="2099-02-01"')" | out)"
echo "9. revise:          $(call revise_invoice "$(jq -n --arg i "$INV" '{id:$i,input:{lines:[{description:"Retainer",quantity:"1",unit_amount:"1250.00"}],reasoning:"Indexation clause: +4.17%."}}')" | out)"
echo "10. get_invoice:    $(call get_invoice "$(jq -n --arg i "$INV" '{id:$i}')" | jq -c '.result.structuredContent | {state, revision: .current_revision.number, total: .current_revision.total, hash: .current_revision.payload_hash[0:12]}')"
echo "11. submit:         $(call submit_invoice "$(jq -n --arg i "$INV" '{id:$i}')" | out)"
echo "12. approve tool:   $(call approve_invoice "$(jq -n --arg i "$INV" '{id:$i}')" | out)"
echo "13. float amount:   $(call create_invoice_draft "$(echo "$INPUT" | jq '.input.idempotency_key="f" | .input.lines[0].unit_amount=1200.5')" | out)"
echo "14. human sees it:  $(curl -s "$BASE/api/v1/invoices/$INV" -H "authorization: Bearer $TOKEN" | jq -c '.data.attributes.state')"
