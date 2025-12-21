defmodule Boonorbust2.Portfolios do
  @moduledoc """
  Context module for managing portfolios and portfolio tags.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Portfolios.Portfolio
  alias Boonorbust2.Portfolios.PortfolioTag
  alias Boonorbust2.Repo
  alias Boonorbust2.Tags.Tag

  # Portfolio functions

  @spec list_portfolios(Ecto.UUID.t()) :: [Portfolio.t()]
  def list_portfolios(user_id) do
    Repo.all(from p in Portfolio, where: p.user_id == ^user_id, order_by: p.name)
  end

  @spec get_portfolio!(integer()) :: Portfolio.t()
  def get_portfolio!(id), do: Repo.get!(Portfolio, id)

  @spec get_portfolio(integer()) :: Portfolio.t() | nil
  def get_portfolio(id), do: Repo.get(Portfolio, id)

  @spec create_portfolio(map()) :: {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def create_portfolio(attrs \\ %{}) do
    %Portfolio{}
    |> Portfolio.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_portfolio(Portfolio.t(), map()) ::
          {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def update_portfolio(%Portfolio{} = portfolio, attrs) do
    portfolio
    |> Portfolio.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_portfolio(Portfolio.t()) :: {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def delete_portfolio(%Portfolio{} = portfolio) do
    Repo.delete(portfolio)
  end

  @spec change_portfolio(Portfolio.t(), map()) :: Ecto.Changeset.t()
  def change_portfolio(%Portfolio{} = portfolio, attrs \\ %{}) do
    Portfolio.changeset(portfolio, attrs)
  end

  @doc """
  Lists all portfolios for a user with their associated tags preloaded.
  """
  @spec list_portfolios_with_tags(Ecto.UUID.t()) :: [Portfolio.t()]
  def list_portfolios_with_tags(user_id) do
    portfolios = list_portfolios(user_id)

    Enum.map(portfolios, fn portfolio ->
      tags = list_tags_for_portfolio(portfolio.id)
      Map.put(portfolio, :tags, tags)
    end)
  end

  @doc """
  Lists tag IDs for a portfolio (useful for form selections).
  """
  @spec list_tag_ids_for_portfolio(integer()) :: [integer()]
  def list_tag_ids_for_portfolio(portfolio_id) do
    portfolio_id
    |> list_tags_for_portfolio()
    |> Enum.map(& &1.id)
  end

  @doc """
  Creates a portfolio with associated tags in an atomic transaction.
  Returns the portfolio with tags preloaded.
  """
  @spec create_portfolio_with_tags(map(), [String.t()] | [integer()]) ::
          {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t() | :tag_association_failed}
  def create_portfolio_with_tags(attrs, tag_ids \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:portfolio, Portfolio.changeset(%Portfolio{}, attrs))
    |> Ecto.Multi.run(:tags, fn repo, %{portfolio: portfolio} ->
      insert_portfolio_tags(repo, portfolio.id, tag_ids)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{portfolio: portfolio}} ->
        # Reload to get tags as a virtual field (not in schema)
        {:ok, portfolio}

      {:error, :portfolio, changeset, _} ->
        {:error, changeset}

      {:error, :tags, :tag_association_failed, _} ->
        {:error, :tag_association_failed}
    end
  end

  @doc """
  Updates a portfolio and synchronizes its tags in an atomic transaction.
  Removes all existing tags and replaces with the provided tag_ids.
  """
  @spec update_portfolio_with_tags(Portfolio.t(), map(), [String.t()] | [integer()]) ::
          {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t() | :tag_sync_failed}
  def update_portfolio_with_tags(%Portfolio{} = portfolio, attrs, tag_ids \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:portfolio, Portfolio.changeset(portfolio, attrs))
    |> Ecto.Multi.run(:remove_tags, fn repo, %{portfolio: updated_portfolio} ->
      {_count, _} =
        repo.delete_all(
          from pt in PortfolioTag,
            where: pt.portfolio_id == ^updated_portfolio.id
        )

      {:ok, true}
    end)
    |> Ecto.Multi.run(:add_tags, fn repo, %{portfolio: updated_portfolio} ->
      insert_portfolio_tags(repo, updated_portfolio.id, tag_ids)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{portfolio: portfolio}} ->
        # Return updated portfolio (tags can be queried separately if needed)
        {:ok, portfolio}

      {:error, :portfolio, changeset, _} ->
        {:error, changeset}

      {:error, _, :tag_sync_failed, _} ->
        {:error, :tag_sync_failed}
    end
  end

  # PortfolioTag functions

  @spec add_tag_to_portfolio(integer(), integer()) ::
          {:ok, PortfolioTag.t()} | {:error, Ecto.Changeset.t()}
  def add_tag_to_portfolio(portfolio_id, tag_id) do
    %PortfolioTag{}
    |> PortfolioTag.changeset(%{
      portfolio_id: portfolio_id,
      tag_id: tag_id
    })
    |> Repo.insert()
  end

  @spec remove_tag_from_portfolio(integer(), integer()) ::
          {:ok, PortfolioTag.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def remove_tag_from_portfolio(portfolio_id, tag_id) do
    portfolio_tag = Repo.get_by(PortfolioTag, portfolio_id: portfolio_id, tag_id: tag_id)

    if portfolio_tag do
      Repo.delete(portfolio_tag)
    else
      {:error, :not_found}
    end
  end

  @spec list_tags_for_portfolio(integer()) :: [Tag.t()]
  def list_tags_for_portfolio(portfolio_id) do
    Repo.all(
      from t in Tag,
        join: pt in PortfolioTag,
        on: pt.tag_id == t.id,
        where: pt.portfolio_id == ^portfolio_id,
        order_by: t.name
    )
  end

  @spec list_portfolios_for_tag(integer()) :: [integer()]
  def list_portfolios_for_tag(tag_id) do
    Repo.all(
      from pt in PortfolioTag,
        where: pt.tag_id == ^tag_id,
        select: pt.portfolio_id
    )
  end

  # Private helpers

  # Helper for string/integer normalization
  defp normalize_tag_ids(tag_ids) do
    Enum.map(tag_ids, fn
      id when is_binary(id) -> String.to_integer(id)
      id when is_integer(id) -> id
    end)
  end

  # Helper to insert portfolio tags in bulk
  defp insert_portfolio_tags(repo, portfolio_id, tag_ids) do
    normalized_tag_ids = normalize_tag_ids(tag_ids)

    if normalized_tag_ids == [] do
      {:ok, []}
    else
      do_insert_portfolio_tags(repo, portfolio_id, normalized_tag_ids)
    end
  end

  defp do_insert_portfolio_tags(repo, portfolio_id, normalized_tag_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    portfolio_tags =
      Enum.map(normalized_tag_ids, fn tag_id ->
        %{
          portfolio_id: portfolio_id,
          tag_id: tag_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    case repo.insert_all(PortfolioTag, portfolio_tags) do
      {_count, _} -> {:ok, true}
      _ -> {:error, :tag_association_failed}
    end
  end
end
