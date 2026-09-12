defmodule Boonorbust2.Irr do
  @moduledoc """
  XIRR (money-weighted rate of return) calculation.

  `xirr/2` is a pure bisection solver: given an ordered list of `{date, amount}`
  cash flows already netted into a single currency, it solves for the annualized
  rate `r` that makes their net present value zero. No I/O, no database access.

  `calculate_portfolio_irr/1` is the orchestrator: it assembles a user's full
  cash-flow history from the database (transactions, dividend income, today's
  portfolio value), converts each flow to the user's preferred currency, and
  delegates to `xirr/2`.
  """

  alias Boonorbust2.Accounts
  alias Boonorbust2.Dashboard
  alias Boonorbust2.ExchangeRates
  alias Boonorbust2.HistoricalExchangeRates
  alias Boonorbust2.HistoricalIndexPrices
  alias Boonorbust2.IndexPrices
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.PortfolioTransactions
  alias Boonorbust2.RealizedProfits

  @low_rate_bound -0.999_999
  @high_rate_bound 100.0
  @default_tolerance 1.0e-6
  @default_max_iterations 100
  @benchmark_ticker "VWRA.L"

  @doc """
  Solves for the XIRR of an ordered list of `{date, amount}` cash flows.

  Returns `{:ok, rate}` where `rate` is the annualized rate as a float
  (e.g. `0.2` for 20%), or `{:error, reason}` when no valid rate can be
  determined:

    * `:no_sign_change` - cash flows are all the same sign (or empty)
    * `:no_time_variance` - all cash flows fall on the same date
    * `:no_bracket_found` - no sign change found within the solver's rate bounds
    * `:max_iterations_exceeded` - solver did not converge within the iteration cap
  """
  @spec xirr([{Date.t(), Decimal.t() | number()}], keyword()) ::
          {:ok, float()} | {:error, atom()}
  def xirr(cash_flows, opts \\ [])

  def xirr([], _opts), do: {:error, :no_sign_change}

  def xirr(cash_flows, opts) do
    amounts = Enum.map(cash_flows, fn {_date, amount} -> to_float(amount) end)

    cond do
      not has_sign_change?(amounts) -> {:error, :no_sign_change}
      not has_time_variance?(cash_flows) -> {:error, :no_time_variance}
      true -> solve(cash_flows, opts)
    end
  end

  @doc """
  Computes a user's portfolio-wide XIRR across all assets.

  Assembles cash flows from every buy/sell `PortfolioTransaction` (dated at
  `transaction_date`), every dividend-income `RealizedProfit` (dated at the
  dividend's `pay_date`), and today's total converted market value across all
  positions (a final terminal inflow). Historical flows are converted to the
  user's preferred currency using the exchange rate as of each flow's own date;
  today's terminal value is converted using the live exchange rate.

  Capital-gain `RealizedProfit` records are not included as separate cash flows
  — the originating sell transaction's `amount` already is that cash flow.

  Returns `{:ok, rate}` or `{:error, reason}` from `xirr/2` unchanged, or
  `{:error, reason}` if a historical exchange rate could not be fetched for a
  needed date — the latter never falls back to a live rate.
  """
  @spec calculate_portfolio_irr(String.t()) :: {:ok, float()} | {:error, term()}
  def calculate_portfolio_irr(user_id) when is_binary(user_id) do
    user_currency = Accounts.get_user_by_id(user_id).currency

    with {:ok, transaction_flows} <- transaction_cash_flows(user_id, user_currency),
         {:ok, dividend_flows} <- dividend_cash_flows(user_id, user_currency) do
      terminal_flow = terminal_cash_flow(user_id, user_currency)
      xirr(transaction_flows ++ dividend_flows ++ [terminal_flow])
    end
  end

  @doc """
  Computes the XIRR of a hypothetical VWRA (Vanguard FTSE All-World UCITS ETF)
  position replaying the user's actual cash-flow timing and amounts.

  Reuses the same transaction and dividend cash flows as
  `calculate_portfolio_irr/1`, but instead of tracking the user's real
  holdings, converts each flow's amount to USD and treats it as a buy/sell of
  VWRA units at that date's closing price (`-usd_amount / price_on_date`,
  which covers buys, sells, and dividends uniformly since a buy is already a
  negative flow and a sell/dividend a positive one). The terminal flow is the
  resulting net unit balance valued at today's live VWRA price, converted to
  the user's currency at today's live exchange rate.

  Returns `{:ok, rate}` or `{:error, reason}` from `xirr/2` unchanged, or
  `{:error, reason}` if a historical exchange rate or VWRA price could not be
  fetched for a needed date — never falls back to a partial result.
  """
  @spec calculate_benchmark_irr(String.t()) :: {:ok, float()} | {:error, term()}
  def calculate_benchmark_irr(user_id) when is_binary(user_id) do
    user_currency = Accounts.get_user_by_id(user_id).currency

    with {:ok, transaction_flows} <- transaction_cash_flows(user_id, user_currency),
         {:ok, dividend_flows} <- dividend_cash_flows(user_id, user_currency),
         {:ok, net_units} <-
           benchmark_net_units(transaction_flows ++ dividend_flows, user_currency),
         {:ok, terminal_flow} <- benchmark_terminal_flow(net_units, user_currency) do
      xirr(transaction_flows ++ dividend_flows ++ [terminal_flow])
    end
  end

  defp benchmark_net_units(flows, user_currency) do
    flows
    |> Enum.reduce_while({:ok, Decimal.new(0)}, fn {date, amount}, {:ok, net_units} ->
      with {:ok, usd_amount} <- convert_to_usd(amount, date, user_currency),
           {:ok, price} <- benchmark_price_on(date) do
        units_delta = usd_amount |> Decimal.negate() |> Decimal.div(Decimal.from_float(price))
        {:cont, {:ok, Decimal.add(net_units, units_delta)}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp convert_to_usd(amount, _date, "USD"), do: {:ok, amount}

  defp convert_to_usd(amount, date, user_currency) do
    with {:ok, rates} <- HistoricalExchangeRates.get_rates(date, user_currency),
         rate when rate != nil <- Map.get(rates, "USD") do
      {:ok, Decimal.mult(amount, Decimal.from_float(rate))}
    else
      nil -> {:error, :currency_not_found}
      {:error, _reason} = error -> error
    end
  end

  defp benchmark_price_on(date) do
    if Date.compare(date, Date.utc_today()) == :lt do
      HistoricalIndexPrices.get_price(date, @benchmark_ticker)
    else
      IndexPrices.get_latest_price(@benchmark_ticker)
    end
  end

  defp benchmark_terminal_flow(net_units, user_currency) do
    with {:ok, price} <- IndexPrices.get_latest_price(@benchmark_ticker) do
      usd_value = Decimal.mult(net_units, Decimal.from_float(price))
      converted = usd_value |> Money.new!("USD") |> ExchangeRates.convert_money(user_currency)
      {:ok, {Date.utc_today(), converted.amount}}
    end
  end

  defp transaction_cash_flows(user_id, user_currency) do
    user_id
    |> PortfolioTransactions.list_all_for_user()
    |> Enum.reduce_while({:ok, []}, fn transaction, {:ok, flows} ->
      date = DateTime.to_date(transaction.transaction_date)

      case convert_to_currency(transaction.amount, date, user_currency) do
        {:ok, converted} ->
          {:cont, {:ok, [{date, signed_amount(transaction.action, converted)} | flows]}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
    |> reverse_flows()
  end

  defp signed_amount("buy", %Money{amount: amount}), do: Decimal.negate(amount)
  defp signed_amount("sell", %Money{amount: amount}), do: amount

  defp dividend_cash_flows(user_id, user_currency) do
    user_id
    |> RealizedProfits.list_dividend_income_by_user()
    |> Enum.reduce_while({:ok, []}, fn realized_profit, {:ok, flows} ->
      date = realized_profit.dividend.pay_date

      case convert_to_currency(realized_profit.amount, date, user_currency) do
        {:ok, %Money{amount: amount}} -> {:cont, {:ok, [{date, amount} | flows]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> reverse_flows()
  end

  defp reverse_flows({:ok, flows}), do: {:ok, Enum.reverse(flows)}
  defp reverse_flows({:error, _reason} = error), do: error

  defp terminal_cash_flow(user_id, user_currency) do
    total_value =
      user_id
      |> PortfolioPositions.list_latest_positions()
      |> Dashboard.enrich_positions_for_dashboard(user_id, user_currency)
      |> PortfolioPositions.calculate_total_portfolio_value(user_currency)

    {Date.utc_today(), total_value.amount}
  end

  defp convert_to_currency(%Money{} = money, date, target_currency) do
    source_currency = money |> Money.to_currency_code() |> Atom.to_string()

    if source_currency == target_currency do
      {:ok, money}
    else
      convert_at_historical_rate(money, date, source_currency, target_currency)
    end
  end

  defp convert_at_historical_rate(money, date, source_currency, target_currency) do
    with {:ok, rates} <- HistoricalExchangeRates.get_rates(date, source_currency),
         rate when rate != nil <- Map.get(rates, target_currency) do
      converted_amount = Decimal.mult(money.amount, Decimal.from_float(rate))
      {:ok, Money.new!(converted_amount, target_currency)}
    else
      nil -> {:error, :currency_not_found}
      {:error, _reason} = error -> error
    end
  end

  defp solve(cash_flows, opts) do
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)
    max_iterations = Keyword.get(opts, :max_iterations, @default_max_iterations)
    t0 = earliest_date(cash_flows)
    npv_fun = fn rate -> npv(cash_flows, t0, rate) end

    bisect(npv_fun, @low_rate_bound, @high_rate_bound, tolerance, max_iterations)
  end

  defp bisect(npv_fun, low, high, tolerance, max_iterations) do
    npv_low = npv_fun.(low)
    npv_high = npv_fun.(high)

    cond do
      abs(npv_low) < tolerance -> {:ok, low}
      abs(npv_high) < tolerance -> {:ok, high}
      same_sign?(npv_low, npv_high) -> {:error, :no_bracket_found}
      true -> bisect_step(npv_fun, low, npv_low, high, tolerance, max_iterations)
    end
  end

  defp bisect_step(_npv_fun, _low, _npv_low, _high, _tolerance, 0) do
    {:error, :max_iterations_exceeded}
  end

  defp bisect_step(npv_fun, low, npv_low, high, tolerance, iterations_left) do
    mid = (low + high) / 2
    npv_mid = npv_fun.(mid)

    cond do
      abs(npv_mid) < tolerance ->
        {:ok, mid}

      same_sign?(npv_mid, npv_low) ->
        bisect_step(npv_fun, mid, npv_mid, high, tolerance, iterations_left - 1)

      true ->
        bisect_step(npv_fun, low, npv_low, mid, tolerance, iterations_left - 1)
    end
  end

  defp npv(cash_flows, t0, rate) do
    Enum.reduce(cash_flows, 0.0, fn {date, amount}, acc ->
      years = Date.diff(date, t0) / 365.0
      acc + to_float(amount) / :math.pow(1 + rate, years)
    end)
  end

  defp earliest_date(cash_flows) do
    cash_flows
    |> Enum.map(fn {date, _amount} -> date end)
    |> Enum.min_by(&{&1.year, &1.month, &1.day})
  end

  defp has_sign_change?(amounts) do
    Enum.any?(amounts, &(&1 > 0)) and Enum.any?(amounts, &(&1 < 0))
  end

  defp has_time_variance?(cash_flows) do
    cash_flows
    |> Enum.map(fn {date, _amount} -> date end)
    |> Enum.uniq()
    |> length() > 1
  end

  defp same_sign?(a, b), do: (a >= 0 and b >= 0) or (a < 0 and b < 0)

  defp to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp to_float(number) when is_number(number), do: number * 1.0
end
