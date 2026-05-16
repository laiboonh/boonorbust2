defmodule Boonorbust2.DividendSources.Digrin do
  @moduledoc false
  alias Boonorbust2.DividendSources.DateParser

  @spec fetch(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, []) do
      {:ok, %{status: 200, body: body}} ->
        case Floki.parse_document(body) do
          {:ok, document} -> parse_response(document)
          {:error, _} -> {:error, "Failed to parse HTML document"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec parse_response(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_response(document) do
    rows = Floki.find(document, "table tbody tr")
    dividends = rows |> Enum.map(&parse_row/1) |> Enum.reject(&is_nil/1)

    if Enum.empty?(dividends) do
      {:error, "No valid dividend data found"}
    else
      {:ok, dividends}
    end
  end

  defp parse_row(row) do
    cells = Floki.find(row, "td")
    ex_date_text = cell_text(cells, 0)
    pay_date_text = cell_text(cells, 1)
    amount_text = cell_text(cells, 2)

    if String.contains?(amount_text, "Upcoming") or amount_text == "N/A" do
      nil
    else
      parse_dividend_data(amount_text, ex_date_text, pay_date_text)
    end
  end

  defp cell_text(cells, index) do
    cells
    |> Enum.at(index)
    |> then(fn c -> if c, do: Floki.text(c), else: "" end)
    |> String.trim()
  end

  defp parse_dividend_data(amount_text, ex_date_text, pay_date_text) do
    with {:ok, {currency, amount}} <- parse_amount(amount_text),
         {:ok, ex_date} <- DateParser.parse_date(ex_date_text) do
      pay_date =
        case DateParser.parse_date(pay_date_text) do
          {:ok, date} -> date
          _ -> nil
        end

      %{ex_date: ex_date, pay_date: pay_date, value: amount, currency: currency}
    else
      _ -> nil
    end
  end

  defp parse_amount(text) do
    case Regex.run(~r/([\d\.]+)\s+([A-Z]{3})/, text) do
      [_, amount, currency] ->
        case Decimal.parse(amount) do
          {decimal, _} -> {:ok, {currency, decimal}}
          :error -> {:error, "Invalid amount format"}
        end

      _ ->
        {:error, "Invalid digrin amount format"}
    end
  end
end
