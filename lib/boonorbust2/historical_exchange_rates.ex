defmodule Boonorbust2.HistoricalExchangeRates do
  @moduledoc """
  Fetches and persists historical exchange rates from Frankfurter.

  Unlike `Boonorbust2.ExchangeRates` (which caches the current rate with a
  1-hour TTL), historical rates never change once published, so they are
  persisted forever in the `historical_exchange_rates` table, keyed on
  `(date, base_currency)`.
  """

  require Logger

  import Ecto.Query, warn: false

  alias Boonorbust2.HistoricalExchangeRates.HistoricalExchangeRate
  alias Boonorbust2.Repo

  @doc """
  Gets historical exchange rates for the given date and base currency.

  Returns the persisted quotes map if already fetched, otherwise fetches
  from the Frankfurter API and persists the result forever.

  Returns `{:ok, rates}` on success or `{:error, reason}` on failure.
  """
  @spec get_rates(Date.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_rates(date, base_currency) when is_binary(base_currency) do
    case get_persisted_rates(date, base_currency) do
      %HistoricalExchangeRate{rates: rates} ->
        {:ok, rates}

      nil ->
        fetch_and_persist_rates(date, base_currency)
    end
  end

  # Private Functions

  defp get_persisted_rates(date, base_currency) do
    Repo.get_by(HistoricalExchangeRate, date: date, base_currency: base_currency)
  end

  defp fetch_and_persist_rates(date, base_currency) do
    case fetch_from_api(date, base_currency) do
      {:ok, rates} ->
        persist_rates(date, base_currency, rates)
        {:ok, rates}

      error ->
        error
    end
  end

  defp fetch_from_api(date, base_currency) do
    api_url = get_api_url(date, base_currency)
    Logger.info("Fetching historical exchange rates from API: #{api_url}")

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(api_url, []) do
      {:ok, %{status: 200, body: body}} ->
        parse_api_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("API returned status #{status}: #{inspect(body)}")
        {:error, {:api_error, status}}

      {:error, reason} = error ->
        Logger.error("Failed to fetch historical exchange rates: #{inspect(reason)}")
        error
    end
  end

  defp parse_api_response(body) when is_list(body) do
    case build_rates_map(body) do
      {:ok, rates} -> {:ok, rates}
      :error -> unexpected_response_format(body)
    end
  end

  defp parse_api_response(body), do: unexpected_response_format(body)

  defp build_rates_map(entries) do
    Enum.reduce_while(entries, {:ok, %{}}, fn
      %{"quote" => quote_currency, "rate" => rate}, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, quote_currency, rate)}}

      _invalid_entry, _acc ->
        {:halt, :error}
    end)
  end

  defp unexpected_response_format(body) do
    Logger.error("Unexpected API response format: #{inspect(body)}")
    {:error, :invalid_response}
  end

  defp persist_rates(date, base_currency, rates) do
    attrs = %{date: date, base_currency: base_currency, rates: rates}

    %HistoricalExchangeRate{}
    |> HistoricalExchangeRate.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:date, :base_currency])
  end

  defp get_api_url(date, base_currency) do
    "https://api.frankfurter.dev/v2/rates?date=#{Date.to_iso8601(date)}&base=#{base_currency}"
  end
end
