# Lesson 4 · Payment destinations and settlement rails

*Part II: Financial intent* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 5](05-invoice-revisions.md)

## Goal

Model *where money goes* precisely enough that it cannot silently change and
cannot be inferred from the currency.

## Concept

A currency is not a rail. USDC arrives on Ethereum, Arbitrum or Base; CHF
arrives by bank transfer to an IBAN. A destination names currency, network and
address; the network decides the rail, the rail decides the address format.
Destinations are immutable but retirable (`active → deactivated | superseded`).
Deep dive: [concepts/payment-destinations.md](../concepts/payment-destinations.md).

## Code to inspect

- `lib/tauros/revenue/network.ex`: which network carries which currency, and its rail
- `lib/tauros/revenue/address.ex`: format vs checksum (bech32m, IBAN mod-97; EVM format only, and why)
- `lib/tauros/revenue/payment_destination.ex`: no action accepts the address after create; the state machine retires it

## Run it

```bash
mix test test/tauros/revenue/payment_destination_test.exs
```

In the app: **Destinations** → open one → see network, rail and state; deactivate it.

## Break it

```elixir
Tauros.Revenue.create_payment_destination(%{label: "x", currency: :BTC, network: :ethereum,
  address: "0x1234567890123456789012345678901234567890"}, actor: agent)
# a Taproot address with one character changed:
Tauros.Revenue.create_payment_destination(%{label: "x", currency: :BTC, network: :bitcoin,
  address: "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcs"}, actor: agent)
```

## Why it fails

`Validations.Receivable`: Ethereum does not carry BTC; and the second address
has the right shape but a wrong bech32m checksum. (The test suite once used an
address with exactly this kind of flaw; the old regex accepted it.)

## What to remember

- Currency, network, rail and address are four different facts.
- Checksums catch typos; shapes do not. Say which one you check.
- Payment details never change in place; they are retired and replaced.

**Next:** [Lesson 5 · Invoice revisions and the financial payload](05-invoice-revisions.md)
