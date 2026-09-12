# ADR-0004 implementation plan: Benchmark IRR against a global index

Companion to [ADR-0004](0004-irr-benchmark-against-global-index.md). That ADR records the
decision; this document is the concrete, file-level plan to execute it.

## Context

`Boonorbust2.Irr.calculate_portfolio_irr/1` (ADR-0003) gives a user their own money-weighted
return, but not whether that return is any good — the natural comparison is "what if I'd put the
same money into a global index instead, at the same times?" ADR-0004 resolves every design
question for this (methodology, benchmark instrument, data source, currency conversion, caching,
error handling, UI placement). This plan turns that ADR into concrete file changes.

The core idea: replay the exact same cash-flow stream that already feeds
`calculate_portfolio_irr/1` into a hypothetical VWRA (Vanguard FTSE All-World UCITS ETF, Acc, LSE,
USD) position, and run the same XIRR solver over it, so the two numbers are directly comparable on
the dashboard.

Key implementation insight found while planning: because a buy is a negative cash flow and a
sell/dividend is a positive cash flow (existing convention in `Irr`), the hypothetical units
bought/sold at any flow is always `-usd_amount / price_that_day` — one formula covers buys,
sells, and dividends uniformly. This lets the new code reuse `Irr`'s existing private
`transaction_cash_flows/2` and `dividend_cash_flows/2` directly instead of re-deriving anything
from raw transactions.

## New modules (mirroring existing live/historical FX split)

The app already has this exact pattern for currency: `Boonorbust2.ExchangeRates` (live, Cachex
1-hour TTL) vs `Boonorbust2.HistoricalExchangeRates` (persisted forever, keyed by date). Mirror it
for index prices instead of introducing a new shape:

1. **`Boonorbust2.HistoricalIndexPrices`** (`lib/boonorbust2/historical_index_prices.ex`) — for
   strictly-past dates. `get_price(date, ticker) :: {:ok, float()} | {:error, term()}`. Checks a
   new `historical_index_prices` table (keyed on `(date, ticker)`, mirrors
   `HistoricalExchangeRates.get_persisted_rates/2`); on miss, calls Yahoo's chart API
   (`https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?period1=...&period2=...&interval=1d`,
   verified working with no API key), requesting a ~10-calendar-day trailing window ending at
   `date` to absorb weekends/holidays, picks the closing price of the latest trading day `<=
   date` (skipping `null` closes, which Yahoo returns for non-trading days in a range), and
   persists it **under the originally-requested `date`** (not the resolved trading day) so
   subsequent lookups for that date hit the cache directly — this is the "snap to prior trading
   day" rule from the ADR, implemented as a lookup-time rule rather than an error fallback.
   Genuine fetch failures (network error, non-200, unparseable body, or no valid close anywhere
   in the window) return `{:error, reason}` and nothing is persisted — matches
   `HistoricalExchangeRates`'s strict-failure precedent.
   - New schema `lib/boonorbust2/historical_index_prices/historical_index_price.ex`, fields
     `date :date`, `ticker :string`, `close :float`, `timestamps()` — mirrors
     `HistoricalExchangeRates.HistoricalExchangeRate` exactly (that module stores `rates` as a raw
     float map, not pre-converted to Decimal; same choice here for `close`).
   - New migration `priv/repo/migrations/<ts>_create_historical_index_prices.exs`: table with a
     unique index on `[:date, :ticker]`, same shape as the `historical_exchange_rates` migration.

2. **`Boonorbust2.IndexPrices`** (`lib/boonorbust2/index_prices.ex`) — for **today only**.
   `get_latest_price(ticker) :: {:ok, float()} | {:error, term()}`. A "today's" close isn't
   immutable (market may still be open, or Yahoo hasn't published it yet), so this is *not*
   persisted to the forever-cache table — it mirrors `ExchangeRates`'s Cachex TTL pattern instead
   (`@cache_name :index_prices_cache`, 1-hour TTL, keyed by ticker). Internally: same Yahoo chart
   API call as above with a short trailing window, take the latest valid close in the window
   (today's if the market's already printed one, otherwise the most recent prior day's — same
   "last known close" idea, just without needing to match a specific calendar date).
   - Deliberately duplicates the small Yahoo-fetch-and-parse logic from
     `HistoricalIndexPrices` rather than extracting a shared abstraction — matches this
     codebase's existing precedent of `ExchangeRates` and `HistoricalExchangeRates` each having
     their own independent `fetch_from_api`/`parse_api_response` despite hitting conceptually
     similar APIs.

No new HTTP client behavior needed — both use the existing
`Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)` indirection,
so both are testable via the existing `Boonorbust2.HTTPClientMock` (Mox) exactly like
`historical_exchange_rates_test.exs` and `exchange_rates_test.exs` already do. No API key/secret
needed (Yahoo's chart endpoint is unauthenticated), so no new config.

## Extend `Boonorbust2.Irr` (`lib/boonorbust2/irr.ex`)

Add:

```elixir
@benchmark_ticker "VWRA.L"

@spec calculate_benchmark_irr(String.t()) :: {:ok, float()} | {:error, term()}
def calculate_benchmark_irr(user_id) when is_binary(user_id) do
  user_currency = Accounts.get_user_by_id(user_id).currency

  with {:ok, transaction_flows} <- transaction_cash_flows(user_id, user_currency),
       {:ok, dividend_flows} <- dividend_cash_flows(user_id, user_currency),
       {:ok, net_units} <- benchmark_net_units(transaction_flows ++ dividend_flows, user_currency),
       {:ok, terminal_flow} <- benchmark_terminal_flow(net_units, user_currency) do
    xirr(transaction_flows ++ dividend_flows ++ [terminal_flow])
  end
end
```

Private helpers:
- `benchmark_net_units(flows, user_currency)` — folds over the already-computed, already-signed
  `{date, amount}` flows (reusing `transaction_cash_flows/2` and `dividend_cash_flows/2`
  unchanged), converting each `amount` from `user_currency` to USD via
  `HistoricalExchangeRates.get_rates(date, user_currency)` (same historical-FX mechanism already
  used for the real IRR, just with `user_currency` as the base instead of the asset's currency),
  looking up that date's VWRA price via `benchmark_price_on/1`, and accumulating
  `Decimal.negate(usd_amount / price)` — the single formula that covers buys, sells, and
  dividends per the insight above. Fails fast (`{:halt, error}`) on any missing rate/price,
  matching the existing `reduce_while` style in `transaction_cash_flows/2`.
- `benchmark_price_on(date)` — `HistoricalIndexPrices.get_price(date, @benchmark_ticker)` for
  `date < Date.utc_today()`, else `IndexPrices.get_latest_price(@benchmark_ticker)`. (Real
  transaction/dividend dates are always `<=` today, but a transaction dated today should use the
  live path, not risk caching an intraday price forever.)
- `benchmark_terminal_flow(net_units, user_currency)` — `IndexPrices.get_latest_price/1` for
  today's VWRA price, values `net_units * price` in USD, converts to `user_currency` via
  `Boonorbust2.ExchangeRates.convert_money/2` (the **live** conversion path — mirrors how the real
  IRR's own terminal flow is converted at today's live rate, not a historical rate), returns
  `{Date.utc_today(), converted_decimal_amount}`.

`@doc` on the new public function explaining the replay semantics (mirroring the existing
`@doc` style on `calculate_portfolio_irr/1`); no `@spec`/`@doc` on the new private helpers, per
project convention.

## Dashboard UI

- `lib/boonorbust2_web/live/dashboard_live.ex`: add a second `assign_async(:benchmark_irr, fn ->
  load_benchmark_irr(user_id) end)` alongside the existing `:irr` one, following the exact same
  `{:ok, %{...}}` / logged-`{:error, reason}` shape as `load_irr/1`.
- `lib/boonorbust2_web/live/dashboard_live.html.heex`: a second card directly under the existing
  "Portfolio IRR" card, titled "vs Global Index (VWRA)", using the same `<.async_result>` /
  `:loading` / `:failed` slot pattern. Show the delta (`portfolio IRR − benchmark IRR`) as the
  headline stat with a sign-colored value (green for outperforming, red/gray for underperforming),
  and the raw benchmark IRR as a smaller secondary line — this needs both `@irr` and
  `@benchmark_irr` async results resolved together, so use nested `<.async_result>` (outer on
  `@benchmark_irr`, and inside its success slot check `@irr.ok?`/`@irr.result` to compute the
  delta; if `@irr` hasn't resolved yet, show just the raw benchmark number).

## Tests

- `test/boonorbust2/historical_index_prices_test.exs` — mirrors
  `historical_exchange_rates_test.exs` structure: fetch-on-first-call, cache-on-second-call,
  independent caching per `(date, ticker)`, API/network error handling, snap-to-prior-trading-day
  behavior (mock a window response where the exact requested date has no entry/has a `null`
  close, assert the prior day's close is returned and persisted under the requested date).
- `test/boonorbust2/index_prices_test.exs` — mirrors `exchange_rates_test.exs`: TTL cache hit/miss
  behavior, no DB persistence.
- `test/boonorbust2/irr_test.exs` — add a `describe "calculate_benchmark_irr/1"` block mirroring
  the existing `calculate_portfolio_irr/1` tests: build a small buy/sell/dividend history, mock
  the historical FX rates (already-used `expect_historical_rate/3` helper) plus new
  `HistoricalIndexPrices`/`IndexPrices` mocks for VWRA prices on each relevant date, assert the
  resulting rate matches an independently-computed expected `xirr/2` call over the manually-worked
  hypothetical cash-flow/unit-tracking arithmetic (same style as the existing test's
  `expected_cash_flows` list). Also add a "fails without fallback when a VWRA price fetch fails"
  case, mirroring the existing FX-failure test.
- `test/boonorbust2_web/live/dashboard_live_test.exs` (if it exists — check first) — extend to
  assert the new card renders with a benchmark value and delta once both async assigns resolve.

## Verification

- `mix test` — all new and existing tests pass.
- `mix quality` (format + `mix credo --strict`) — required by this repo's pre-commit hooks; run
  before considering the change done.
- Manual: `mix phx.server`, log in, load `/dashboard` for a user with real transaction history,
  confirm both cards render (Portfolio IRR and vs Global Index), confirm the `:loading` state
  briefly appears then resolves, and confirm behavior when simulating a Yahoo failure (temporarily
  point the mock/stub or disconnect network) shows the `:failed` "unavailable" state without
  breaking the rest of the dashboard.
