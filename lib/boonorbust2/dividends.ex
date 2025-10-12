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

    query = from d in Dividend, order_by: [desc: d.date]
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
        dividends =
          Enum.map(body, fn dividend ->
            %{
              date: dividend["date"],
              value: dividend["value"],
              currency: dividend["currency"] || "USD"
            }
          end)

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

    case http_client.get(dividend_url) do
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

  def fetch_dividends(%Asset{dividend_url: dividend_url}) do
    {:error, "Request failed: Unexpected dividend url #{dividend_url}"}
  end

  @spec parse_dividends_sg(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_dividends_sg(document) do
    # Find all dividend rows in the table
    rows = Floki.find(document, "table.table-striped tbody tr")

    dividends =
      rows
      |> Enum.map(fn row ->
        cells = Floki.find(row, "td")

        # First cell contains currency and amount together (e.g., "SGD0.0185")
        currency_amount_text =
          cells
          |> Enum.at(0)
          |> Floki.text()
          |> String.trim()

        # Second cell contains ex-date (e.g., "2006-01-23")
        ex_date_text =
          cells
          |> Enum.at(1)
          |> Floki.text()
          |> String.trim()

        # Parse the data
        with {:ok, {currency, amount}} <- parse_currency_and_amount(currency_amount_text),
             {:ok, date} <- parse_date(ex_date_text) do
          %{
            date: date,
            value: amount,
            currency: currency
          }
        else
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(dividends) do
      {:error, "No valid dividend data found"}
    else
      {:ok, dividends}
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

  @doc """
  Fetches and stores dividends for an asset.

  This will fetch all dividends from the API and insert/update them in the database.
  """
  @spec sync_dividends(Asset.t()) ::
          {:ok, %{inserted: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, String.t()}
  def sync_dividends(%Asset{} = asset) do
    case fetch_dividends(asset) do
      {:ok, dividends} ->
        results =
          Enum.map(dividends, fn dividend_data ->
            attrs = Map.put(dividend_data, :asset_id, asset.id)

            %Dividend{}
            |> Dividend.changeset(attrs)
            |> Repo.insert(
              on_conflict: {:replace, [:value, :currency, :updated_at]},
              conflict_target: [:asset_id, :date]
            )
          end)

        inserted_count = Enum.count(results, fn {status, _} -> status == :ok end)
        error_count = Enum.count(results, fn {status, _} -> status == :error end)

        {:ok, %{inserted: inserted_count, errors: error_count}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
