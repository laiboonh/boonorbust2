defmodule Boonorbust2.PriceSources.AlphaVantage do
  @moduledoc false
  require Logger

  @spec fetch(String.t()) :: {:ok, any()} | {:error, String.t()}
  def fetch(url) do
    access_key = Application.get_env(:boonorbust2, :alphavantage_api_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, params: [apikey: access_key]) do
      {:ok, %{status: 200, body: body}} -> parse_response(body)
      {:ok, %{status: status}} -> {:error, "HTTP request failed with status #{status}"}
      {:error, error} -> {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec parse_response(map()) :: {:ok, any()} | {:error, String.t()}
  def parse_response(%{"Time Series (Daily)" => time_series}) when map_size(time_series) == 0 do
    {:error, "No data available"}
  end

  def parse_response(body) do
    with %{"Time Series (Daily)" => time_series} <- body,
         [first_date | _] <- Map.keys(time_series) |> Enum.sort(:desc),
         %{"4. close" => close_value} <- time_series[first_date] do
      {:ok, close_value}
    else
      %{"Error Message" => error_msg} ->
        {:error, "API error: #{error_msg}"}

      %{"Note" => note} ->
        {:error, "API limit reached: #{note}"}

      %{"Information" => info} ->
        {:error, "API limit reached: #{info}"}

      _ ->
        Logger.error(
          "Invalid response format from AlphaVantage API. Response body: #{inspect(body)}"
        )

        {:error, "Invalid response format"}
    end
  end
end
