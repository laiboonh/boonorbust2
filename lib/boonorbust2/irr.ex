defmodule Boonorbust2.Irr do
  @moduledoc """
  Pure XIRR (money-weighted rate of return) solver.

  Solves for the annualized rate `r` that makes the net present value of an
  ordered list of `{date, amount}` cash flows equal to zero, using bisection.
  No I/O, no database access — cash flows must already be netted into a
  single currency by the caller.
  """

  @low_rate_bound -0.999_999
  @high_rate_bound 100.0
  @default_tolerance 1.0e-6
  @default_max_iterations 100

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
