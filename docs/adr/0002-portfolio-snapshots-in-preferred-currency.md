# ADR-0002: Portfolio snapshots stored in user's preferred currency at time of recording

## Status
Accepted

## Context
Portfolio snapshots record total portfolio value once per day, triggered when the user views the dashboard. The value must be expressed in a single currency for storage.

## Decision
Snapshots are always stored in the user's preferred currency at the time of recording. No currency metadata is stored on the snapshot record itself.

## Consequences
- Simple to implement and query — no per-snapshot currency conversion needed at read time
- If the user changes their preferred currency, historical snapshots are denominated in different currencies, making the time series inconsistent and the portfolio chart misleading across a currency change
- Accepted trade-off: currency changes are rare; correcting historical snapshots on currency change would require re-fetching historical exchange rates and rewriting all past records, which adds significant complexity for a low-frequency event
- Future work: if currency changes become common, consider storing the currency code alongside each snapshot value
