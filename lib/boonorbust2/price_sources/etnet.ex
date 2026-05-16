defmodule Boonorbust2.PriceSources.Etnet do
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
        Logger.error("Price not found on etnet.com.hk page: #{url}")
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
      document
      |> Floki.find("span")
      |> Enum.find_value(&extract_header_txt_price/1)

    case result do
      nil -> {:error, :price_not_found}
      price -> {:ok, price}
    end
  end

  @spec parse_dividends(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_dividends(document) do
    rows = Floki.find(document, "table tr") |> Enum.drop(1)
    dividends = rows |> Enum.map(&parse_hk_row/1) |> Enum.reject(&is_nil/1)

    if Enum.empty?(dividends) do
      {:error, "No valid dividend data found"}
    else
      {:ok, dividends}
    end
  end

  defp extract_header_txt_price({_tag, attrs, [text | _]}) when is_binary(text) do
    with {"class", class_value} <- List.keyfind(attrs, "class", 0),
         true <- String.contains?(class_value, "HeaderTxt") do
      String.trim(text)
    else
      _ -> nil
    end
  end

  defp extract_header_txt_price(_), do: nil

  defp parse_hk_row(row) do
    cells = Floki.find(row, "td")
    particular_text = cell_text(cells, 2)
    ex_date_text = cell_text(cells, 3)
    pay_date_text = extract_hk_pay_date(cells)

    if should_skip?(particular_text, ex_date_text) do
      nil
    else
      build_dividend(particular_text, ex_date_text, pay_date_text)
    end
  end

  defp cell_text(cells, index) do
    cells
    |> Enum.at(index)
    |> then(fn c -> if c, do: Floki.text(c), else: "" end)
    |> String.trim()
  end

  defp extract_hk_pay_date(cells) do
    cond do
      length(cells) >= 8 -> cell_text(cells, 7)
      length(cells) >= 7 -> cell_text(cells, 6)
      true -> ""
    end
  end

  defp should_skip?(particular_text, ex_date_text) do
    String.contains?(particular_text, "No") or ex_date_text == "--"
  end

  defp build_dividend(particular_text, ex_date_text, pay_date_text) do
    with {:ok, {currency, amount}} <- parse_hk_particular(particular_text),
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

  defp parse_hk_particular(text) do
    with {:hkd, [_, amount]} <- {:hkd, Regex.run(~r/HKD\s+([\d\.]+)/, text)},
         {decimal, _} <- Decimal.parse(amount) do
      {:ok, {"HKD", decimal}}
    else
      {:hkd, nil} -> parse_any_currency(text)
      :error -> {:error, "Invalid HKD amount format"}
    end
  end

  defp parse_any_currency(text) do
    case Regex.run(~r/([A-Z]{3})\s+([\d\.]+)/, text) do
      [_, currency, amount] ->
        case Decimal.parse(amount) do
          {decimal, _} -> {:ok, {currency, decimal}}
          :error -> {:error, "Invalid amount format"}
        end

      _ ->
        {:error, "Invalid particular format"}
    end
  end
end
