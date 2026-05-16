defmodule Boonorbust2.PriceSources.ExchangeRateApi do
  @moduledoc false
  require Logger

  @spec fetch(String.t()) :: {:ok, any()} | {:error, String.t()}
  def fetch(url) do
    api_key = Application.get_env(:boonorbust2, :exchange_rate_api_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, auth: {:bearer, api_key}) do
      {:ok, %{status: 200, body: body}} -> parse_response(body)
      {:ok, %{status: status}} -> {:error, "HTTP request failed with status #{status}"}
      {:error, error} -> {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec parse_response(map()) :: {:ok, any()} | {:error, String.t()}
  def parse_response(body) do
    case body do
      %{"conversion_rate" => rate} ->
        {:ok, rate}

      _ ->
        Logger.error(
          "Invalid response format from Exchange Rate API. Response body: #{inspect(body)}"
        )

        {:error, "Invalid response format"}
    end
  end
end
