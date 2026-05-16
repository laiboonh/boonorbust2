defmodule Boonorbust2.PriceSources.Marketstack do
  @moduledoc false
  require Logger

  @spec fetch(String.t()) :: {:ok, any()} | {:error, String.t()}
  def fetch(url) do
    access_key = Application.get_env(:boonorbust2, :price_api_access_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, params: [access_key: access_key]) do
      {:ok, %{status: 200, body: body}} -> parse_response(body)
      {:ok, %{status: status}} -> {:error, "HTTP request failed with status #{status}"}
      {:error, error} -> {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec parse_response(map()) :: {:ok, any()} | {:error, String.t()}
  def parse_response(body) do
    with %{"data" => [first_data | _]} <- body,
         %{"close" => close_value} <- first_data do
      {:ok, close_value}
    else
      %{"data" => []} ->
        {:error, "No data available"}

      _ ->
        Logger.error(
          "Invalid response format from Marketstack API. Response body: #{inspect(body)}"
        )

        {:error, "Invalid response format"}
    end
  end
end
