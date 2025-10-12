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

  def fetch_dividends(%Asset{dividend_url: "https://api.example.com/" <> _rest = dividend_url}) do
    # Example API pattern - replace with actual dividend API provider
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

  def fetch_dividends(%Asset{dividend_url: dividend_url}) do
    {:error, "Request failed: Unexpected dividend url #{dividend_url}"}
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
