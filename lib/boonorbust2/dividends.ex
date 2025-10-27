defmodule Boonorbust2.Dividends do
  @moduledoc """
  Context module for managing dividends.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Dividends.Dividend
  alias Boonorbust2.Repo

  @spec list_dividends(keyword()) :: [Dividend.t()]
  def list_dividends(opts \\ []) do
    asset_id = Keyword.get(opts, :asset_id, nil)

    query = from d in Dividend, order_by: [desc: d.ex_date]
    query = if asset_id, do: where(query, [d], d.asset_id == ^asset_id), else: query

    Repo.all(query)
  end

  @spec get_dividend!(integer()) :: Dividend.t()
  def get_dividend!(id), do: Repo.get!(Dividend, id)

  @spec get_dividend(integer()) :: Dividend.t() | nil
  def get_dividend(id), do: Repo.get(Dividend, id)

  @spec create_dividend(map()) :: {:ok, Dividend.t()} | {:error, Ecto.Changeset.t()}
  def create_dividend(attrs \\ %{}) do
    %Dividend{}
    |> Dividend.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_dividend(Dividend.t(), map()) ::
          {:ok, Dividend.t()} | {:error, Ecto.Changeset.t()}
  def update_dividend(%Dividend{} = dividend, attrs) do
    dividend
    |> Dividend.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_dividend(Dividend.t()) :: {:ok, Dividend.t()} | {:error, Ecto.Changeset.t()}
  def delete_dividend(%Dividend{} = dividend) do
    Repo.delete(dividend)
  end

  @spec change_dividend(Dividend.t(), map()) :: Ecto.Changeset.t()
  def change_dividend(%Dividend{} = dividend, attrs \\ %{}) do
    Dividend.changeset(dividend, attrs)
  end

  @doc """
  Fetches all dividends from the asset's dividend_url.

  Returns a list of all dividend records or an error.
  Different function heads handle different dividend API providers.
  """
  @spec fetch_dividends(Asset.t()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch_dividends(%Asset{dividend_url: nil} = _asset) do
    {:error, "No dividend URL configured"}
  end

  def fetch_dividends(%Asset{dividend_url: "https://eodhd.com/" <> _rest = dividend_url}) do
    # EODHD API pattern
    api_key = Application.get_env(:boonorbust2, :dividend_api_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(dividend_url, params: [api_token: api_key]) do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        dividends = Enum.map(body, &parse_eodhd_dividend/1)
        {:ok, dividends}

      {:ok, %{status: 200, body: body}} ->
        {:error, "Unexpected response format: #{inspect(body)}"}

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_dividends(%Asset{dividend_url: "https://www.dividends.sg/" <> _rest = dividend_url}) do
    # Scrape dividends from dividends.sg website
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(dividend_url, []) do
      {:ok, %{status: 200, body: body}} ->
        case Floki.parse_document(body) do
          {:ok, document} ->
            parse_dividends_sg(document)

          {:error, _reason} ->
            {:error, "Failed to parse HTML document"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_dividends(%Asset{dividend_url: "https://www.etnet.com.hk/" <> _rest = dividend_url}) do
    # Scrape dividends from etnet.com.hk website
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(dividend_url, []) do
      {:ok, %{status: 200, body: body}} ->
        case Floki.parse_document(body) do
          {:ok, document} ->
            parse_dividends_hk(document)

          {:error, _reason} ->
            {:error, "Failed to parse HTML document"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_dividends(%Asset{dividend_url: "https://www.digrin.com/" <> _rest = dividend_url}) do
    # Scrape dividends from digrin.com website
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(dividend_url, []) do
      {:ok, %{status: 200, body: body}} ->
        case Floki.parse_document(body) do
          {:ok, document} ->
            parse_dividends_digrin(document)

          {:error, _reason} ->
            {:error, "Failed to parse HTML document"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_dividends(%Asset{dividend_url: dividend_url}) do
    {:error, "Request failed: Unexpected dividend url #{dividend_url}"}
  end

  @doc """
  Parses dividends from a dividends.sg HTML document.
  This is exposed publicly to allow parsing from a pre-fetched document
  when combining price and dividend fetching.
  """
  @spec parse_dividends_sg_document(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_dividends_sg_document(document), do: parse_dividends_sg(document)

  @doc """
  Parses dividends from an etnet.com.hk HTML document.
  This is exposed publicly to allow parsing from a pre-fetched document
  when combining price and dividend fetching.
  """
  @spec parse_etnet_document(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_etnet_document(document), do: parse_dividends_hk(document)

  @spec parse_dividends_sg(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_dividends_sg(document) do
    # Find all dividend rows in the table
    rows = Floki.find(document, "table.table-striped tbody tr")

    dividends =
      rows
      |> Enum.map(&parse_dividend_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(dividends) do
      {:error, "No valid dividend data found"}
    else
      {:ok, dividends}
    end
  end

  @spec parse_dividends_hk(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_dividends_hk(document) do
    # Find all dividend rows in the table
    # etnet.com.hk uses standard table elements without specific classes
    # We look for tables that contain dividend data (with "Announcement Date" header)
    rows = Floki.find(document, "table tr")

    # Skip the header row (first row)
    data_rows = Enum.drop(rows, 1)

    dividends =
      data_rows
      |> Enum.map(&parse_dividend_hk_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(dividends) do
      {:error, "No valid dividend data found"}
    else
      {:ok, dividends}
    end
  end

  @spec parse_dividends_digrin(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_dividends_digrin(document) do
    # Find all dividend rows in the table
    # digrin.com uses standard table structure with tbody
    rows = Floki.find(document, "table tbody tr")

    dividends =
      rows
      |> Enum.map(&parse_dividend_digrin_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(dividends) do
      {:error, "No valid dividend data found"}
    else
      {:ok, dividends}
    end
  end

  @spec parse_dividend_hk_row(Floki.html_tree()) :: map() | nil
  defp parse_dividend_hk_row(row) do
    cells = Floki.find(row, "td")

    # etnet.com.hk column structure:
    # Column 0: Announcement Date
    # Column 1: Financial Year
    # Column 2: Particular (e.g., "Int Div RMB 0.95 or HKD 1.04048")
    # Column 3: Ex-date
    # Column 4-5: Book Closed Dates
    # Column 6: Payable Date (may vary, so we check last non-empty cell)
    particular_text = extract_cell_text(cells, 2)
    ex_date_text = extract_cell_text(cells, 3)
    pay_date_text = extract_hk_pay_date(cells)

    # Skip rows with no dividend (e.g., "No Int Div", "No 1st Int Div")
    if should_skip_hk_row?(particular_text, ex_date_text) do
      nil
    else
      build_hk_dividend(particular_text, ex_date_text, pay_date_text)
    end
  end

  @spec extract_cell_text([Floki.html_tree()], non_neg_integer()) :: String.t()
  defp extract_cell_text(cells, index) do
    cells
    |> Enum.at(index)
    |> then(fn cell -> if cell, do: Floki.text(cell), else: "" end)
    |> String.trim()
  end

  @spec extract_hk_pay_date([Floki.html_tree()]) :: String.t()
  defp extract_hk_pay_date(cells) do
    # Payable date is at index 6 or 7 depending on row structure
    cond do
      length(cells) >= 8 -> extract_cell_text(cells, 7)
      length(cells) >= 7 -> extract_cell_text(cells, 6)
      true -> ""
    end
  end

  @spec should_skip_hk_row?(String.t(), String.t()) :: boolean()
  defp should_skip_hk_row?(particular_text, ex_date_text) do
    String.contains?(particular_text, "No") or ex_date_text == "--"
  end

  @spec build_hk_dividend(String.t(), String.t(), String.t()) :: map() | nil
  defp build_hk_dividend(particular_text, ex_date_text, pay_date_text) do
    with {:ok, {currency, amount}} <- parse_hk_particular(particular_text),
         {:ok, ex_date} <- parse_date(ex_date_text) do
      pay_date = parse_optional_pay_date(pay_date_text)

      %{
        ex_date: ex_date,
        pay_date: pay_date,
        value: amount,
        currency: currency
      }
    else
      _ -> nil
    end
  end

  @spec parse_optional_pay_date(String.t()) :: Date.t() | nil
  defp parse_optional_pay_date(date_text) do
    case parse_date(date_text) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  @spec parse_dividend_digrin_row(Floki.html_tree()) :: map() | nil
  defp parse_dividend_digrin_row(row) do
    cells = Floki.find(row, "td")

    # Column 0: Ex-dividend date (format: YYYY-MM-DD)
    # Column 1: Payment date (format: YYYY-MM-DD)
    # Column 2: Dividend amount (format: "0.0106 SGD (-0.92%)")
    ex_date_text =
      cells
      |> Enum.at(0)
      |> then(fn cell -> if cell, do: Floki.text(cell), else: "" end)
      |> String.trim()

    pay_date_text =
      cells
      |> Enum.at(1)
      |> then(fn cell -> if cell, do: Floki.text(cell), else: "" end)
      |> String.trim()

    amount_text =
      cells
      |> Enum.at(2)
      |> then(fn cell -> if cell, do: Floki.text(cell), else: "" end)
      |> String.trim()

    # Skip rows with "Upcoming dividend" or invalid data
    if String.contains?(amount_text, "Upcoming") or amount_text == "N/A" do
      nil
    else
      # Parse the data
      with {:ok, {currency, amount}} <- parse_digrin_amount(amount_text),
           {:ok, ex_date} <- parse_date(ex_date_text) do
        # Parse pay_date, but allow it to be nil if parsing fails
        pay_date =
          case parse_date(pay_date_text) do
            {:ok, date} -> date
            _ -> nil
          end

        %{
          ex_date: ex_date,
          pay_date: pay_date,
          value: amount,
          currency: currency
        }
      else
        _ -> nil
      end
    end
  end

  @spec parse_hk_particular(String.t()) :: {:ok, {String.t(), Decimal.t()}} | {:error, String.t()}
  defp parse_hk_particular(text) do
    # Extract currency and amount from formats like:
    # "Fin Div USD 0.13125" or "Sp Div USD 0.11875"
    # "Int Div RMB 0.95 or HKD 1.04048" (multiple currencies - prefer HKD)

    # Try to find HKD amount first (preferred for HK stocks)
    with {:hkd, [_, amount]} <- {:hkd, Regex.run(~r/HKD\s+([\d\.]+)/, text)},
         {decimal, _} <- Decimal.parse(amount) do
      {:ok, {"HKD", decimal}}
    else
      {:hkd, nil} -> parse_any_currency(text)
      :error -> {:error, "Invalid HKD amount format"}
    end
  end

  @spec parse_any_currency(String.t()) :: {:ok, {String.t(), Decimal.t()}} | {:error, String.t()}
  defp parse_any_currency(text) do
    # No HKD found, try any currency
    case Regex.run(~r/([A-Z]{3})\s+([\d\.]+)/, text) do
      [_, currency, amount] ->
        parse_currency_amount(currency, amount)

      _ ->
        {:error, "Invalid particular format"}
    end
  end

  @spec parse_currency_amount(String.t(), String.t()) ::
          {:ok, {String.t(), Decimal.t()}} | {:error, String.t()}
  defp parse_currency_amount(currency, amount) do
    case Decimal.parse(amount) do
      {decimal, _} -> {:ok, {currency, decimal}}
      :error -> {:error, "Invalid amount format"}
    end
  end

  @spec parse_digrin_amount(String.t()) :: {:ok, {String.t(), Decimal.t()}} | {:error, String.t()}
  defp parse_digrin_amount(text) do
    # Extract amount and currency from format like "0.0106 SGD (-0.92%)"
    # Pattern: decimal number, space, 3-letter currency code
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

  # Aggregates dividends by date, summing values for dividends with the same ex-date.
  # When multiple dividends are declared on the same ex-date (e.g., interim + final),
  # they are combined into a single dividend record with the total value.
  @spec aggregate_dividends_by_date([map()]) :: [map()]
  defp aggregate_dividends_by_date(dividends) do
    dividends
    |> Enum.group_by(& &1.ex_date)
    |> Enum.map(fn {ex_date, date_dividends} ->
      # All dividends for the same date should have the same currency and pay_date
      currency = hd(date_dividends).currency
      pay_date = Map.get(hd(date_dividends), :pay_date)

      # Sum all values for this date
      total_value =
        date_dividends
        |> Enum.map(& &1.value)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      %{
        ex_date: ex_date,
        pay_date: pay_date,
        value: total_value,
        currency: currency
      }
    end)
    |> Enum.sort_by(& &1.ex_date, {:desc, Date})
  end

  @spec parse_dividend_row(Floki.html_tree()) :: map() | nil
  defp parse_dividend_row(row) do
    cells = Floki.find(row, "td")
    cell_count = length(cells)

    # Handle rowspan: rows with 7 cells vs rows with 4 cells
    # Full row (7 cells): Year | Yield | Total | Amount | Ex Date | Pay Date | Particulars
    # Rowspan row (4 cells): Amount | Ex Date | Pay Date | Particulars
    {amount_idx, ex_date_idx, pay_date_idx} =
      if cell_count >= 7 do
        {3, 4, 5}
      else
        {0, 1, 2}
      end

    # Extract currency and amount
    currency_amount_text =
      cells
      |> Enum.at(amount_idx)
      |> then(fn cell -> if cell, do: Floki.text(cell), else: "" end)
      |> String.trim()

    # Extract ex-date
    ex_date_text =
      cells
      |> Enum.at(ex_date_idx)
      |> then(fn cell -> if cell, do: Floki.text(cell), else: "" end)
      |> String.trim()

    # Extract pay-date
    pay_date_text =
      cells
      |> Enum.at(pay_date_idx)
      |> then(fn cell -> if cell, do: Floki.text(cell), else: "" end)
      |> String.trim()

    # Parse the data
    with {:ok, {currency, amount}} <- parse_currency_and_amount(currency_amount_text),
         {:ok, ex_date} <- parse_date(ex_date_text) do
      # Parse pay_date, but allow it to be nil if parsing fails
      pay_date =
        case parse_date(pay_date_text) do
          {:ok, date} -> date
          _ -> nil
        end

      %{
        ex_date: ex_date,
        pay_date: pay_date,
        value: amount,
        currency: currency
      }
    else
      _ -> nil
    end
  end

  @spec parse_currency_and_amount(String.t()) ::
          {:ok, {String.t(), Decimal.t()}} | {:error, String.t()}
  defp parse_currency_and_amount(text) do
    # Extract currency code (typically 3 letters at the start) and amount
    # Example: "SGD0.0185" -> {"SGD", 0.0185}
    case Regex.run(~r/^([A-Z]{3})([\d\.]+)/, text) do
      [_, currency, amount] ->
        case Decimal.parse(amount) do
          {decimal, _} -> {:ok, {currency, decimal}}
          :error -> {:error, "Invalid amount format"}
        end

      _ ->
        {:error, "Invalid currency/amount format"}
    end
  end

  @spec parse_date(String.t()) :: {:ok, Date.t()} | {:error, String.t()}
  defp parse_date(date_string) do
    # Try different date formats commonly used
    # Format: DD/MM/YYYY or DD-MM-YYYY
    cond do
      String.match?(date_string, ~r/^\d{1,2}\/\d{1,2}\/\d{4}$/) ->
        [day, month, year] = String.split(date_string, "/")
        parse_date_parts(day, month, year)

      String.match?(date_string, ~r/^\d{1,2}-\d{1,2}-\d{4}$/) ->
        [day, month, year] = String.split(date_string, "-")
        parse_date_parts(day, month, year)

      String.match?(date_string, ~r/^\d{4}-\d{1,2}-\d{1,2}$/) ->
        # ISO format YYYY-MM-DD
        Date.from_iso8601(date_string)

      true ->
        {:error, "Invalid date format"}
    end
  end

  @spec parse_date_parts(String.t(), String.t(), String.t()) ::
          {:ok, Date.t()} | {:error, String.t()}
  defp parse_date_parts(day, month, year) do
    with {day_int, _} <- Integer.parse(day),
         {month_int, _} <- Integer.parse(month),
         {year_int, _} <- Integer.parse(year),
         {:ok, date} <- Date.new(year_int, month_int, day_int) do
      {:ok, date}
    else
      _ -> {:error, "Invalid date"}
    end
  end

  @spec parse_eodhd_dividend(map()) :: map()
  defp parse_eodhd_dividend(dividend) do
    # Parse paymentDate if present (EODHD API uses camelCase)
    pay_date = parse_optional_date(dividend["paymentDate"])

    %{
      ex_date: dividend["date"] |> Date.from_iso8601!(),
      pay_date: pay_date,
      value: dividend["value"] |> Float.to_string(),
      currency: dividend["currency"] || "USD"
    }
  end

  @spec parse_optional_date(String.t() | nil) :: Date.t() | nil
  defp parse_optional_date(nil), do: nil
  defp parse_optional_date(""), do: nil
  defp parse_optional_date(date_str), do: Date.from_iso8601!(date_str)

  @doc """
  Fetches and stores dividends for an asset.

  This will fetch all dividends from the API and insert/update them in the database.
  For each successfully upserted dividend, it will automatically process realized profits
  for all users who held the asset before the ex-date.
  """
  @spec sync_dividends(Asset.t()) ::
          {:ok,
           %{
             inserted: non_neg_integer(),
             errors: non_neg_integer(),
             realized_profits_created: non_neg_integer()
           }}
          | {:error, String.t()}
  def sync_dividends(%Asset{} = asset) do
    case fetch_dividends(asset) do
      {:ok, dividends} ->
        sync_dividends_from_data(asset, dividends)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Syncs dividends from pre-fetched data instead of fetching from URL.
  This is used when combining price and dividend fetching to avoid duplicate HTTP calls.
  """
  @spec sync_dividends_from_data(Asset.t(), [map()]) ::
          {:ok,
           %{
             inserted: non_neg_integer(),
             errors: non_neg_integer(),
             realized_profits_created: non_neg_integer()
           }}
          | {:error, String.t()}
  def sync_dividends_from_data(%Asset{} = asset, dividends) do
    # Group dividends by date and sum values for same date
    aggregated_dividends = aggregate_dividends_by_date(dividends)

    results =
      Enum.map(aggregated_dividends, fn dividend_data ->
        attrs = Map.put(dividend_data, :asset_id, asset.id)

        %Dividend{}
        |> Dividend.changeset(attrs)
        |> Repo.insert(
          on_conflict: {:replace, [:value, :currency, :pay_date, :updated_at]},
          conflict_target: [:asset_id, :ex_date]
        )
      end)

    inserted_count = Enum.count(results, fn {status, _} -> status == :ok end)
    error_count = Enum.count(results, fn {status, _} -> status == :error end)

    # Process realized profits for all successfully upserted dividends
    realized_profits_count =
      results
      |> Enum.filter(fn {status, _} -> status == :ok end)
      |> Enum.map(fn {:ok, dividend} ->
        {:ok, count} = Boonorbust2.RealizedProfits.process_dividend_for_all_users(dividend)
        count
      end)
      |> Enum.sum()

    {:ok,
     %{
       inserted: inserted_count,
       errors: error_count,
       realized_profits_created: realized_profits_count
     }}
  end
end
