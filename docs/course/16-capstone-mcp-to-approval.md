# Lesson 16 · Capstone: from an AI proposal to a human decision

*Part IV: AI capability* · [Course map](../LEARNING-PATH.md)

**Before this lesson:** all of the above, the app running with demo data
(`mix setup && mix phx.server`), and `curl` and `jq`.

## Goal

Play both sides of Tauros end to end: an AI client proposing through MCP, and
a human approver deciding in the browser. Then explain every boundary you
crossed.

## Run it

**As the AI client** (one terminal):

```bash
source docs/examples/mcp_env.sh                          # a fresh agent key, from REST
mcp "$KEY" tools/list '{}' | jq '[.result.tools[].name]' # 1. discover
CUSTOMER=$(call list_customers '{}' | jq -r '.result.structuredContent.results[0].id')
DEST=$(call list_payment_destinations '{}' | jq -r '.result.content[0].text | fromjson | .[0].id')
INPUT=$(jq -n --arg c "$CUSTOMER" --arg d "$DEST" '{input:{idempotency_key:"capstone",
  customer_id:$c, payment_destination_id:$d, currency:"USDC", due_date:"2099-01-31",
  lines:[{description:"Retainer",quantity:"1",unit_amount:"1200.00"}],
  reasoning:"Retainer per the agreement."}}')
INVOICE=$(call create_invoice_draft "$INPUT" | jq -r .result.structuredContent.id)   # 2. draft
call create_invoice_draft "$INPUT" | out                 # 3. replay: the same id
call revise_invoice "{\"id\":\"$INVOICE\",\"input\":{\"lines\":[{\"description\":\"Retainer\",\"quantity\":\"1\",\"unit_amount\":\"1250.00\"}],\"reasoning\":\"Indexation +4.17%.\"}}" | out   # 4. revise
call submit_invoice "{\"id\":\"$INVOICE\"}" | out        # 5. submit: pending_approval
call approve_invoice "{\"id\":\"$INVOICE\"}" | out       # 6. Tool not found
curl -s -X PATCH localhost:4000/api/v1/invoices/$INVOICE/approve -H "authorization: Bearer $KEY" \
  -H 'content-type: application/vnd.api+json' \
  -d '{"data":{"type":"invoice","id":"'$INVOICE'","attributes":{"revision_id":"'$INVOICE'","payload_hash":"'$(printf '0%.0s' {1..64})'"}}}' \
  | jq '.errors[0].status'                               # 7. "403"
```

**The agent stops here.** It cannot finish the job; a human must.

**As the human** (browser, `demo@tauros.local`):

8. **Overview**: the new proposal is in "Needs your attention" and in Recent
   activity ("MCP agent … submitted the invoice … · via mcp").
9. Open it in **Needs review**. Check: revision **2**, 1250.00 USDC, the
   agent's reasoning, "Proposed by MCP agent …, decided by you".
10. Approve it, or request changes and watch the invoice say it is waiting
    for the agent.
11. On the invoice, read the **History**: proposed, revised and submitted via
    mcp; decided by you via ui.

```bash
call get_invoice "{\"id\":\"$INVOICE\"}" | jq '.result.structuredContent | {state, decision: .current_revision.approval}'
```

## Explain it

Answer in one line each, pointing at code:

1. Which layer refused step 6, and which refused step 7? (capability vs authority)
2. Why did step 3 return the same invoice, and what would make it a conflict?
3. What exactly did you approve in step 10: the invoice, or something narrower?
4. If the agent had revised between steps 9 and 10, what would have happened?
5. Where would you look, a year later, to prove who proposed this and who approved which fingerprint?

If you can answer all five, you can answer the course's question:
*how do you let an AI take part in a financial workflow without giving it
financial authority?*

## Where to go next

- [ROADMAP.md](../ROADMAP.md): Epic 5 (full history), Epic 6 (issuing and reconciliation)
- [concepts/eventual-consistency.md](../concepts/eventual-consistency.md): what happens after approval
