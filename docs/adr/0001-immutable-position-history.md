# ADR-0001: Immutable position history — one Position per Transaction

## Status
Accepted

## Context
Portfolio positions need to track how holdings change over time. The alternative is a single mutable Position record per asset that gets updated in place on every transaction.

## Decision
Each Transaction produces a new Position record. Positions are never updated destructively — recalculation rewrites the full history by upserting one record per transaction (conflict target: `portfolio_transaction_id`). The latest Position for an asset is the current holding state.

## Consequences
- Full audit trail: you can reconstruct holdings at any past point in time
- Recalculation is safe to re-run — idempotent by design
- Slightly more storage than a single mutable record, but negligible at this scale
- Callers always read the "latest position" — never assume a single canonical record exists independently of transactions
