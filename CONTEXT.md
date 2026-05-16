# Context

## Glossary

### Asset
A financial instrument that can be held in a portfolio — including stocks, ETFs, and REITs. Has a price denominated in a currency and may optionally distribute dividends. Currency codes (e.g. USD, SGD) are used only for denomination; they are not Assets.

### Tag
A user-defined label attached to one or more Assets. An Asset can have multiple Tags.

### Portfolio
A named grouping of Assets defined by a set of Tags, used to view a filtered subset of holdings. Not the totality of what is owned. An Asset can appear in multiple Portfolios simultaneously by sharing Tags.

### All Portfolio Positions
The complete set of current holdings across all assets — what the user owns in total. Not a named entity; referenced as "all portfolio positions" to distinguish from a filtered Portfolio view.

### Position
The holding state for an Asset at a point in time — recording quantity on hand, average price, and total cost basis. Each Transaction produces a new Position record, building an immutable history. The current holding state is always the latest Position for an asset. Do not say "current position record" — say "latest position".

### Average Price
The weighted average cost per unit for an Asset, recalculated on each buy Transaction. Represents the cost basis used to calculate Realized Profit on a sale. Unaffected by sell Transactions. This is the only cost basis method used — FIFO and other methods are not supported.

### Transaction
A buy or sell event for an Asset. For a buy: `amount = (quantity × price) + commission`. For a sell: `amount = (quantity × price) − commission` (commission reduces net proceeds). A Transaction always produces a new Position.

### Capital Gain
Profit or loss locked in from selling an Asset, calculated as `(sell price − average price) × quantity sold`. A loss is represented as a negative capital gain — there is no separate "loss" concept.

### Dividend Income
Cash received from an Asset that distributes dividends. Distinct from Capital Gain but stored in the same `RealizedProfit` table, differentiated by which foreign key is populated (`portfolio_transaction_id` for capital gains, `dividend_id` for dividend income).

### Realized Profit
The umbrella term for Capital Gain and Dividend Income combined. Use the specific term (Capital Gain or Dividend Income) when the distinction matters; use Realized Profit only when referring to the total across both types.

### Price Sync
Automatic fetching of current market price for an Asset from an external source (Marketstack, AlphaVantage, dividends.sg, etnet.com.hk), selected by the format of `price_url`. Price sync only runs for Assets with current holdings (`quantity_on_hand > 0`) — fully sold Assets stop receiving updates to reduce external API calls. A 12-hour rate limit prevents redundant fetches.

### Dividend
A per-unit cash distribution from an Asset. A user is eligible if they hold the asset before the ex-date. Dividend income is recorded as a Realized Profit when dividend data is synced — which may be before the pay-date. The pay-date on the Dividend record indicates when cash is actually received; UI surfaces upcoming vs recent payments by pay-date. The recorded income is `dividend value × quantity held × (1 − withholding tax rate)`. Withholding tax always applies — a rate of zero means no tax is deducted.

### Unrealized Profit
The paper gain or loss on a current holding — `(current market price − average price) × quantity on hand`. Calculated at display time; never stored. A loss is represented as a negative value.

### Portfolio Snapshot
A record of total portfolio value for a user on a given date, always expressed in the user's preferred currency at the time of recording. One snapshot per user per day — triggered when the user views the dashboard. **Known limitation**: if the user changes their preferred currency, historical snapshots are denominated in different currencies, making the time series inconsistent. Do not compare snapshots across a currency change without accounting for this.

### Preferred Currency
A display-only setting on the User. Transactions and positions are always stored in the Asset's currency. The preferred currency is used solely to convert values for dashboard display — it does not affect how data is recorded.

### Current Converted Market Value
The current market value of a Position expressed in the user's preferred currency — `current market price × quantity on hand`, converted from the Asset's currency. Referred to as `converted_total_value` in code. Do not say "total value" alone — prefer "current converted market value" to make the currency conversion explicit.
