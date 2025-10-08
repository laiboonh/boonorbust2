defmodule Boonorbust2.ExchangeRates do
  @moduledoc """
  Fetches and caches exchange rates for various base currencies from exchangerate-api.com.
  Supports any base currency (USD, SGD, HKD, etc.) with 1-hour cache TTL per currency.
  """

  require Logger

  @cache_name :exchange_rates_cache
  # Cache for 1 hour (in milliseconds)
  @cache_ttl :timer.hours(1)

  @doc """
  Gets exchange rates for the specified base currency. Returns cached data if available,
  otherwise fetches from the API and caches the result.

  Returns `{:ok, rates}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Boonorbust2.ExchangeRates.get_rates("USD")
      {:ok, %{"SGD" => 1.35, "EUR" => 0.92, ...}}

      iex> Boonorbust2.ExchangeRates.get_rates("SGD")
      {:ok, %{"USD" => 0.74, "EUR" => 0.68, ...}}

  """
  @spec get_rates(String.t()) :: {:ok, map()} | {:error, term()}
  def get_rates(base_currency \\ "USD") when is_binary(base_currency) do
    cache_key = cache_key(base_currency)

    case Cachex.get(@cache_name, cache_key) do
      {:ok, nil} ->
        # Cache miss - fetch from API
        fetch_and_cache_rates(base_currency)

      {:ok, rates} ->
        # Cache hit
        {:ok, rates}

      {:error, reason} = error ->
        Logger.error("Cachex error: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Fetches a specific exchange rate for a currency pair.

  ## Examples

      iex> Boonorbust2.ExchangeRates.get_rate("USD", "SGD")
      {:ok, 1.35}

      iex> Boonorbust2.ExchangeRates.get_rate("SGD", "USD")
      {:ok, 0.74}

  """
  @spec get_rate(String.t(), String.t()) :: {:ok, float()} | {:error, term()}
  def get_rate(base_currency, target_currency)
      when is_binary(base_currency) and is_binary(target_currency) do
    case get_rates(base_currency) do
      {:ok, rates} ->
        case Map.get(rates, target_currency) do
          nil -> {:error, :currency_not_found}
          rate -> {:ok, rate}
        end

      error ->
        error
    end
  end

  @doc """
  Forces a refresh of the cached exchange rates for the specified base currency.
  """
  @spec refresh(String.t()) :: {:ok, map()} | {:error, term()}
  def refresh(base_currency \\ "USD") when is_binary(base_currency) do
    cache_key = cache_key(base_currency)
    Cachex.del(@cache_name, cache_key)
    fetch_and_cache_rates(base_currency)
  end

  # Private Functions

  defp cache_key(base_currency) do
    "#{String.downcase(base_currency)}_rates"
  end

  defp fetch_and_cache_rates(base_currency) do
    case fetch_from_api(base_currency) do
      {:ok, rates} ->
        cache_rates(base_currency, rates)
        {:ok, rates}

      error ->
        error
    end
  end

  defp fetch_from_api(base_currency) do
    api_url = get_api_url(base_currency)
    Logger.info("Fetching exchange rates from API: #{api_url}")

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(api_url, []) do
      {:ok, %{status: 200, body: body}} ->
        parse_api_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("API returned status #{status}: #{inspect(body)}")
        {:error, {:api_error, status}}

      {:error, reason} = error ->
        Logger.error("Failed to fetch exchange rates: #{inspect(reason)}")
        error
    end
  end

  defp parse_api_response(%{"result" => "success", "conversion_rates" => rates})
       when is_map(rates) do
    {:ok, rates}
  end

  defp parse_api_response(body) do
    Logger.error("Unexpected API response format: #{inspect(body)}")
    {:error, :invalid_response}
  end

  defp cache_rates(base_currency, rates) do
    cache_key = cache_key(base_currency)

    case Cachex.put(@cache_name, cache_key, rates, ttl: @cache_ttl) do
      {:ok, true} ->
        Logger.info("Successfully cached #{base_currency} exchange rates for #{@cache_ttl}ms")
        :ok

      {:error, reason} ->
        Logger.error("Failed to cache exchange rates: #{inspect(reason)}")
        :error
    end
  end

  defp get_api_url(base_currency) do
    api_key = Application.get_env(:boonorbust2, :exchange_rate_api_key)
    "https://v6.exchangerate-api.com/v6/#{api_key}/latest/#{base_currency}"
  end
end
