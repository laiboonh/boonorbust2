# ADR-0004: Benchmark portfolio IRR against a global index

## Status
Accepted

## Context
`Boonorbust2.Irr.calculate_portfolio_irr/1` (ADR-0003) gives a user their own money-weighted return, but not whether that return is any good — the natural comparison is "what if I'd put the same money into a global index instead, at the same times?" Answering that requires replaying the same cash-flow timing/amounts into a hypothetical index position, which in turn requires historical *equity* price data — a capability the app does not have today (`Boonorbust2.Assets`/`PriceSources` only fetch a single *current* scraped price per asset; only FX has a historical-lookback module, `HistoricalExchangeRates`).

## Decision

**Methodology**: same-cash-flow replay, not a lump-sum/CAGR comparison. Every cash flow that already feeds the real IRR is mirrored into a hypothetical VWRA position at the same date and dollar amount, and the same `Irr.xirr/2` solver is run over the resulting stream:
- Buy → hypothetical VWRA purchase (negative flow), units bought = USD amount / VWRA close on that date
- Sell → hypothetical VWRA withdrawal (positive flow), same USD amount, sized in units at that date's close
- Dividend (`RealizedProfits.list_dividend_income_by_user/1`, same set ADR-0003 uses) → hypothetical VWRA withdrawal, identical treatment to a sell. Real dividends already count as a withdrawal in the real IRR, so the benchmark stream must mirror that exact same dollar amount on the same `pay_date` — otherwise the two cash-flow streams wouldn't be comparable. This is independent of the benchmark fund's own distribution policy (see below).
- Terminal value → units held today × today's VWRA close

This makes the two cash-flow streams (real vs. hypothetical) identical in every date and amount; the only difference is which asset backs the position and which price series sizes the terminal value.

**Benchmark instrument**: VWRA (Vanguard FTSE All-World UCITS ETF, Acc, LSE, USD-denominated) — the broadest common "global index" interpretation (~3,700 stocks incl. emerging markets). Accumulating share class deliberately chosen so the benchmark's own dividends never need to be sourced or modeled as separate cash flows — its price already reflects total return internally. Hardcoded as a module constant for now; not user-configurable. Scope matches ADR-0003 exactly: one benchmark IRR per user, whole portfolio, not per-asset or per-named-Portfolio.

**Price data source**: Yahoo Finance's unauthenticated chart API (`query1.finance.yahoo.com/v8/finance/chart/VWRA.L`) — verified working with no API key. Stooq, a common free alternative, is currently blocked by an anti-bot JS proof-of-work challenge and was rejected for that reason. A paid/keyed API (Alpha Vantage, Twelve Data, etc.) was rejected as unnecessary operational overhead — this app has no other paid API dependency.

**Persistence**: a new `historical_index_prices` table, keyed on `(date, ticker)`, mirroring the fetch-once-cache-forever pattern of `historical_exchange_rates` — a closed trading day's close never changes, so once fetched it's never refetched.

**Non-trading days**: `transaction_date` is free-entry and not validated against a market calendar, so it can land on a weekend/holiday when VWRA didn't trade. Frankfurter already resolves this transparently for FX (returns the prior business day's rate). Yahoo's chart API does not — it just omits non-trading days — so the lookup explicitly snaps to the most recent prior trading day's close. This is a lookup-time rule, not an error fallback.

**Currency conversion**: each flow is converted to USD using `HistoricalExchangeRates.get_rates/2` at that flow's own date (same mechanism and same per-date granularity ADR-0003 already established for the real IRR), buys/sells VWRA units in USD, then converts the final USD terminal value back to the user's reporting currency at today's live rate.

**Failure handling**: strict, matching ADR-0003's precedent exactly — if any historical VWRA price or FX rate needed by the calculation can't be fetched, the entire benchmark calculation fails (`{:error, reason}`). No fallback to a nearby date's price/rate on fetch failure, no silent exclusion of the affected flow.

**UI placement**: a second dashboard card next to the existing "Portfolio IRR" card — "vs Global Index" — showing the benchmark IRR and the delta (portfolio IRR − benchmark IRR) as the headline number. Computed via the same `assign_async` pattern as the real IRR, so a Yahoo outage or cold price cache never blocks the rest of the dashboard.

## Consequences
- Requires a new historical price-fetching module (mirroring `HistoricalExchangeRates`'s shape) and a new migration for `historical_index_prices`
- First calculation for a user with a long transaction history costs one Yahoo Finance call per previously-unseen VWRA trading date; bounded by cache growth per date, not per calculation, since prices never change once fetched
- A Yahoo Finance outage makes the benchmark card temporarily unavailable, but — because it's `assign_async` — does not affect the real Portfolio IRR card or the rest of the dashboard
- The benchmark ticker is currently a hardcoded constant; per-user configurability (or additional benchmark options like MSCI World or S&P 500) can be added later without touching the storage schema, since `historical_index_prices` is already keyed by ticker
- No per-asset or per-named-Portfolio benchmark breakdown, matching the same limitation already accepted for the real IRR in ADR-0003
