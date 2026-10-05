# Payment destinations: immutable, but retirable

A payment destination that silently changes is a classic fraud vector: change
the IBAN on file, and the next payment goes to the attacker. Tauros therefore
treats destinations as **immutable records with a lifecycle**.

## A currency is not a rail

The first version of Tauros grouped currencies by "settlement rail": BTC meant
Bitcoin, USDC meant Ethereum, EUR meant an IBAN. That is wrong in ways that
matter:

- USDC is issued on Ethereum, Arbitrum, Base and more. An address that is
  valid on one network can receive funds on another, but the payment is only
  seen where it was actually sent.
- A currency does not imply a bank scheme, and an IBAN is not a wallet.
- Address rules belong to the network (and its rail), not to the currency:
  ETH and USDC on Arbitrum share one address format.

So a destination names all three, and the domain checks that they fit:

```text
currency ── carried by? ──▶ network ── belongs to ──▶ rail ── decides ──▶ address format
  USDC                       arbitrum                 evm                 0x + 40 hex
  CHF                        iban                     bank_transfer       IBAN + mod-97
  BTC                        bitcoin                  bitcoin             bc1p + bech32m
```

(`Tauros.Revenue.Currency`, `Tauros.Revenue.Network`, `Tauros.Revenue.Address`.)

## Format validation vs. real validation

A regular expression checks shape. It does not catch typos. A checksum does,
and Tauros verifies the checksum where core Erlang can:

| Rail | Tauros verifies | Honest limit |
| --- | --- | --- |
| bitcoin | bech32m checksum (BIP-350) and a 32-byte Taproot program | other address types are refused, not validated |
| bank_transfer | ISO 13616 mod-97 | not the country-specific account structure |
| evm | shape only | EIP-55 casing needs Keccak-256, which OTP does not provide |

While adding the bech32m check we found that the Taproot address the test
suite had been using had an **invalid checksum**: the shape-only rule had
accepted it all along. That is the lesson in one line.

None of these checks proves that anyone controls the address. Only a human who
knows the counterparty, or a test payment, can do that.

## Immutable details, explicit lifecycle

| Need | Model |
| --- | --- |
| a destination's details must never change under an invoice | no action accepts `label`, `currency`, `network` or `address` after create |
| a compromised or obsolete destination must stop being used | `deactivate`: `active → deactivated` |
| a typo must be corrected | register the replacement with `supersedes_id`; the old one becomes `superseded` in the same transaction |
| history must stay true | nothing is deleted; old invoices still point at the destination they named |

Only `active` destinations can be used by a new invoice revision, be
submitted, or be approved. Approval locks the destination row, so deactivation
and approval cannot interleave halfway.

Try it: [exercise 4](../EXERCISES.md#4-mutate-approved-intent) shows why an
edit after approval produces a different hash.
