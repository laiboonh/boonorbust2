defmodule Boonorbust2.PriceSources.DividendsSg do
  @moduledoc false
  require Logger

  alias Boonorbust2.DividendSources.DateParser

  @spec fetch_price(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def fetch_price(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    with {:ok, %{status: 200, body: body}} <- http_client.get(url, []),
         {:ok, document} <- Floki.parse_document(body),
         {:ok, price} <- parse_price(document) do
      {:ok, price}
    else
      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, :price_not_found} ->
        Logger.error("Price not found on dividends.sg page: #{url}")
        {:error, "Price not found on page"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @spec fetch_dividends(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch_dividends(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, []) do
      {:ok, %{status: 200, body: body}} ->
        case Floki.parse_document(body) do
          {:ok, document} -> parse_dividends(document)
          {:error, _} -> {:error, "Failed to parse HTML document"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec fetch_combined(String.t()) :: {:ok, {String.t(), [map()]}} | {:error, String.t()}
  def fetch_combined(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, []) do
      {:ok, %{status: 200, body: body}} ->
        with {:ok, document} <- Floki.parse_document(body),
             {:ok, price} <- parse_price(document),
             {:ok, dividends} <- parse_dividends(document) do
          {:ok, {price, dividends}}
        else
          {:error, :price_not_found} -> {:error, "Price not found on page"}
          {:error, reason} -> {:error, reason}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec parse_price(Floki.html_tree()) :: {:ok, String.t()} | {:error, :price_not_found}
  def parse_price(document) do
    result =
      [
        ".company-quote-line strong",
        ".dividend-company-price",
        ".col-md-8 h4 span",
        "h4 span",
        "div.col-md-8 > h4 > span"
      ]
      |> Enum.find_value(&extract_price_from_selector(document, &1))

    case result do
      nil -> {:error, :price_not_found}
      price -> {:ok, price}
    end
  end

  @spec parse_dividends(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_dividends(document) do
    rows = Floki.find(document, "table.table-striped tbody tr")
    dividends = rows |> Enum.map(&parse_row/1) |> Enum.reject(&is_nil/1)

    if Enum.empty?(dividends) do
      {:error, "No valid dividend data found"}
    else
      {:ok, dividends}
    end
  end

  defp extract_price_from_selector(document, selector) do
    case Floki.find(document, selector) do
      [] -> nil
      elements -> extract_numeric_price(elements)
    end
  end

  defp extract_numeric_price(elements) do
    text = Floki.text(elements) |> String.trim()

    case Regex.run(~r/\d+(?:\.\d+)?/, text) do
      [price] -> price
      _ -> nil
    end
  end

  defp parse_row(row) do
    cells = Floki.find(row, "td")
    cell_count = length(cells)

    {amount_idx, ex_date_idx, pay_date_idx} =
      if cell_count >= 7, do: {3, 4, 5}, else: {0, 1, 2}

    currency_amount_text = cell_text(cells, amount_idx)
    ex_date_text = cell_text(cells, ex_date_idx)
    pay_date_text = cell_text(cells, pay_date_idx)

    with {:ok, {currency, amount}} <- parse_currency_and_amount(currency_amount_text),
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

  defp cell_text(cells, index) do
    cells
    |> Enum.at(index)
    |> then(fn c -> if c, do: Floki.text(c), else: "" end)
    |> String.trim()
  end

  defp parse_currency_and_amount(text) do
    case Regex.run(~r/^([A-Z]{3})\s*([\d\.]+(?:[Ee][+-]?\d+)?)/, text) do
      [_, currency, amount] ->
        case Decimal.parse(amount) do
          {decimal, _} -> {:ok, {currency, decimal}}
          :error -> {:error, "Invalid amount format"}
        end

      _ ->
        {:error, "Invalid currency/amount format"}
    end
  end
end
