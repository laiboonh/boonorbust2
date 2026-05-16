defmodule Boonorbust2.DividendSources.Divvydiary do
  @moduledoc false
  @spec fetch(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    opts = [
      headers: [
        {"user-agent",
         "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
      ]
    ]

    case http_client.get(url, opts) do
      {:ok, %{status: 200, body: body}} -> parse_response(body)
      {:ok, %{status: status}} -> {:error, "HTTP request failed with status #{status}"}
      {:error, error} -> {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec parse_response(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_response(body) do
    case Regex.run(~r/\\"dividends\\":\[(\{\\"id\\".+?)\]/s, body) do
      [_, escaped_json] ->
        ("[" <> String.replace(escaped_json, ~S(\"), ~S(")) <> "]")
        |> parse_json()

      nil ->
        {:error, "No dividend data found on page"}
    end
  end

  defp parse_json(json_str) do
    case Jason.decode(json_str) do
      {:ok, entries} ->
        dividends =
          entries
          |> Enum.reject(fn e -> Map.get(e, "forecast", false) end)
          |> Enum.map(&parse_entry/1)
          |> Enum.reject(&is_nil/1)

        if Enum.empty?(dividends) do
          {:error, "No valid dividend data found"}
        else
          {:ok, dividends}
        end

      {:error, _} ->
        {:error, "Failed to parse dividend JSON"}
    end
  end

  defp parse_entry(%{
         "exDate" => ex_date_str,
         "payDate" => pay_date_str,
         "amount" => amount,
         "currency" => currency
       }) do
    with {:ok, ex_date} <- Date.from_iso8601(ex_date_str),
         {:ok, pay_date} <- Date.from_iso8601(pay_date_str),
         {decimal, _} <- Decimal.parse(to_string(amount)) do
      %{ex_date: ex_date, pay_date: pay_date, value: decimal, currency: currency}
    else
      _ -> nil
    end
  end

  defp parse_entry(_), do: nil
end
