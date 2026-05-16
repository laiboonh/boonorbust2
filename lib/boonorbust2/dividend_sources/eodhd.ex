defmodule Boonorbust2.DividendSources.Eodhd do
  @moduledoc false
  @spec fetch(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch(url) do
    api_key = Application.get_env(:boonorbust2, :dividend_api_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, params: [api_token: api_key]) do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        {:ok, Enum.map(body, &parse_dividend/1)}

      {:ok, %{status: 200, body: body}} ->
        {:error, "Unexpected response format: #{inspect(body)}"}

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp parse_dividend(dividend) do
    %{
      ex_date: dividend["date"] |> Date.from_iso8601!(),
      pay_date: parse_date(dividend["paymentDate"]),
      value: dividend["value"] |> Float.to_string(),
      currency: dividend["currency"] || "USD"
    }
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_str), do: Date.from_iso8601!(date_str)
end
