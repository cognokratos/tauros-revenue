# Eventual consistency and reconciliation

In money movement, these are **different facts**, established at different
times by different systems:

```text
invoice issued        Tauros decided the customer owes money
payment initiated     someone says they are paying (a customer, a signer such as Arktos)
payment observed      a rail reports a transfer (a mempool tx, a bank notice)
payment confirmed     the rail considers it final (N confirmations, settled credit)
payment reconciled    Tauros matched it to an invoice, an amount and a currency
```

Modelling settlement as `send transaction → paid` merges five facts into one.
That is how systems end up "paid" for transactions that were dropped,
re-organised, sent to the wrong address or underpaid.

## The planned model

- **Inbound events are stored before they are interpreted.** A
  `SettlementEvent` (source, external id, raw payload, received at) has an
  identity on `(source, external_id)`, so redelivery is harmless (see
  [idempotency](idempotency.md)).
- **A `Payment` has its own lifecycle**:
  `observed → confirmed → reconciled`, plus the side branches `failed` and
  `unmatched`. It is separate from the invoice's.
- **Reconciliation is a deterministic action.** It matches a confirmed payment
  to an invoice by destination (one of the agent's payment destinations), network, currency and
  reference, then records an allocation. The invoice moves to `partially_paid` or
  `paid` only through that action, comparing the sum of allocations with the
  total.
- **Time is explicit.** Confirmation thresholds per rail, and "not seen within N
  hours" alerts, run as AshOban jobs driven by record state. They are not timers
  living in a process.
- **Disagreements are states, not exceptions.** An overpayment, an unknown
  sender or a currency mismatch become `unmatched` payments for a human to
  resolve. They are never silently "close enough".

## The role of the LLM

An agent may *read* this state and explain it: "Acme paid 800 of 1,200 USDC;
the payment is confirmed but not yet reconciled". It may also *propose* a match
for an unmatched payment. Only the reconciliation action, run by an authorized
actor, changes balances. See [intent, authority, execution](intent-authority-execution.md).

## The boundary with Arktos

Tauros knows the **financial intent**: what is owed, by whom, and to which public
address. [Arktos](https://github.com/cognokratos/arktos-wallet) knows the
**cryptographic authority**: keys, custody and signing. When Tauros pays out
(for example a refund), it will hand an approved, idempotent payment instruction to
an optional Arktos adapter and then wait to *observe* the result like any other
external event. Tauros never holds a key.
