defmodule Boonorbust2.Dividends do
  @moduledoc """
  Context module for managing dividends.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Dividends.Dividend
  alias Boonorbust2.PriceSources.DividendsSg
  alias Boonorbust2.PriceSources.Etnet
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

  def fetch_dividends(%Asset{dividend_url: url}) do
    Boonorbust2.DividendSources.fetch_dividends(url)
  end

  @doc """
  Parses dividends from a dividends.sg HTML document.
  """
  @spec parse_dividends_sg_document(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_dividends_sg_document(document),
    do: DividendsSg.parse_dividends(document)

  @doc """
  Parses dividends from an etnet.com.hk HTML document.
  """
  @spec parse_etnet_document(Floki.html_tree()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_etnet_document(document),
    do: Etnet.parse_dividends(document)

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
