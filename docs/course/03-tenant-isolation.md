# Lesson 3 · Tenant isolation

*Part I: Identity and ownership* · [Course map](../LEARNING-PATH.md) · Next: [Lesson 4](04-payment-destinations.md)

## Goal

Understand why policies on reads are not enough when a command *references*
other records, and how Tauros refuses foreign ids without leaking anything.

## Concept

An invoice proposal names a customer and a payment destination by id. The
caller chose those ids. Tauros never trusts them: it loads each record and
compares its owner with the invoice's agent. An id that belongs to someone
else and an id that does not exist get **the same error**, so the answer never
reveals whether another tenant's record exists.

## Code to inspect

- `lib/tauros/revenue/invoice_revision/validations/usable_references.ex`: loads with `authorize?: false` on purpose, then compares `agent_id`
- `lib/tauros/revenue/invoice_revision.ex`: the validation runs `before_action?: true`, inside the transaction

## Run it

```bash
mix test test/tauros/revenue/invoice_test.exs
```

The describe block "an invoice only combines the agent's own records" is this lesson.

## Break it

Lab: [Exercise 1 · Break ownership](../EXERCISES.md#1-break-ownership), then the
same attack over MCP: [Exercise 11 · Cross-tenant request](../EXERCISES.md#11-cross-tenant-request).

## Why it fails

`UsableReferences` finds that the customer's `agent_id` is not the invoice's
and returns `is not one of this agent's customers`, the same text it returns
for an unknown id. Note that it is a *sibling* agent of the same human that is
refused too: ownership is per agent, not per human.

## What to remember

- References in a command are untrusted input; load and compare.
- Unknown and foreign must look identical.
- Isolation is per agent: one human's agents cannot borrow each other's records.

**Next:** [Lesson 4 · Payment destinations and settlement rails](04-payment-destinations.md)
