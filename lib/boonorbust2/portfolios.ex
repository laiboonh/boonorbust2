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
  def list_portfolios(user_id) when is_binary(user_id) do
    Repo.all(from p in Portfolio, where: p.user_id == ^user_id, order_by: p.name)
  end

  @spec get_portfolio(integer()) :: Portfolio.t() | nil
  def get_portfolio(id) when is_integer(id), do: Repo.get(Portfolio, id)

  @doc """
  Deletes a portfolio by ID, including its associated portfolio tags.
  """
  @spec delete_portfolio_by_id(integer()) :: :ok
  def delete_portfolio_by_id(id) when is_integer(id) do
    tags_query = from(pt in PortfolioTag, where: pt.portfolio_id == ^id)
    portfolio_query = from(p in Portfolio, where: p.id == ^id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:tags, tags_query)
    |> Ecto.Multi.delete_all(:portfolio, portfolio_query)
    |> Repo.transaction()

    :ok
  end

  @doc """
  Lists all portfolios for a user with their associated tags in a single query.
  Each tag carries its stored `target_allocation_percent` for that portfolio.
  """
  @spec list_portfolios_with_tags(Ecto.UUID.t()) :: [map()]
  def list_portfolios_with_tags(user_id) when is_binary(user_id) do
    query =
      from p in Portfolio,
        left_join: pt in PortfolioTag,
        on: pt.portfolio_id == p.id,
        left_join: t in Tag,
        on: t.id == pt.tag_id,
        where: p.user_id == ^user_id,
        order_by: [asc: p.name, asc: t.name],
        select: {p, t, pt.target_allocation_percent}

    query
    |> Repo.all()
    |> Enum.group_by(fn {portfolio, _tag, _percent} -> portfolio end, fn {_portfolio, tag,
                                                                          percent} ->
      annotate_tag(tag, percent)
    end)
    |> Enum.map(fn {portfolio, tags} ->
      Map.put(portfolio, :tags, Enum.filter(tags, & &1))
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Loads a single portfolio with its tags preloaded.
  Each tag carries its stored `target_allocation_percent` for that portfolio.
  """
  @spec load_portfolio_with_tags(integer()) :: %{:tags => [any()], optional(any()) => any()}
  def load_portfolio_with_tags(portfolio_id) when is_integer(portfolio_id) do
    query =
      from p in Portfolio,
        left_join: pt in PortfolioTag,
        on: pt.portfolio_id == p.id,
        left_join: t in Tag,
        on: t.id == pt.tag_id,
        where: p.id == ^portfolio_id,
        order_by: [asc: t.name],
        select: {p, t, pt.target_allocation_percent}

    query
    |> Repo.all()
    |> case do
      [] ->
        get_portfolio(portfolio_id) |> Map.put(:tags, [])

      results ->
        {portfolio, _, _} = hd(results)

        tags =
          results
          |> Enum.map(fn {_, tag, percent} -> annotate_tag(tag, percent) end)
          |> Enum.filter(& &1)

        Map.put(portfolio, :tags, tags)
    end
  end

  @doc """
  Validates that target allocation percentages for a portfolio's selected tags
  are all present and sum to exactly 100.00. An empty map (no tags selected)
  is valid, since tags remain optional on a portfolio.
  """
  @spec validate_tag_allocations(%{
          (String.t() | integer()) => String.t() | number() | Decimal.t() | nil
        }) :: :ok | {:error, String.t()}
  def validate_tag_allocations(tag_allocations) when tag_allocations == %{}, do: :ok

  def validate_tag_allocations(tag_allocations) when is_map(tag_allocations) do
    case parse_percentages(tag_allocations) do
      {:ok, percentages} -> validate_percentages_sum(percentages)
      :error -> {:error, "is required for every selected tag"}
    end
  end

  @doc """
  Creates a portfolio with associated tag allocations in an atomic transaction.
  Returns the portfolio with tags preloaded. `tag_allocations` maps each
  selected tag id to its target allocation percentage.
  """
  @spec create_portfolio_with_tags(map(), %{
          (String.t() | integer()) => String.t() | number() | Decimal.t() | nil
        }) :: {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def create_portfolio_with_tags(attrs, tag_allocations \\ %{})
      when is_map(attrs) and is_map(tag_allocations) do
    case validate_tag_allocations(tag_allocations) do
      :ok ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:portfolio, Portfolio.changeset(%Portfolio{}, attrs))
        |> Ecto.Multi.run(:tags, fn repo, %{portfolio: portfolio} ->
          insert_portfolio_tags(repo, portfolio.id, tag_allocations)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{portfolio: portfolio}} ->
            {:ok, portfolio}

          {:error, :portfolio, changeset, _} ->
            {:error, changeset}

          {:error, :tags, _tag_changeset, _} ->
            {:error, allocation_error_changeset(%Portfolio{}, attrs)}
        end

      {:error, message} ->
        {:error, allocation_error_changeset(%Portfolio{}, attrs, message)}
    end
  end

  @doc """
  Updates a portfolio and synchronizes its tag allocations in an atomic
  transaction. Removes all existing tags and replaces with the provided
  `tag_allocations` (a map of selected tag id to target allocation percentage).
  """
  @spec update_portfolio_with_tags(Portfolio.t(), map(), %{
          (String.t() | integer()) => String.t() | number() | Decimal.t() | nil
        }) :: {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def update_portfolio_with_tags(%Portfolio{} = portfolio, attrs, tag_allocations \\ %{})
      when is_map(attrs) and is_map(tag_allocations) do
    case validate_tag_allocations(tag_allocations) do
      :ok ->
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
          insert_portfolio_tags(repo, updated_portfolio.id, tag_allocations)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{portfolio: portfolio}} ->
            {:ok, portfolio}

          {:error, :portfolio, changeset, _} ->
            {:error, changeset}

          {:error, :add_tags, _tag_changeset, _} ->
            {:error, allocation_error_changeset(portfolio, attrs)}
        end

      {:error, message} ->
        {:error, allocation_error_changeset(portfolio, attrs, message)}
    end
  end

  # PortfolioTag functions

  @spec list_tags_for_portfolio(integer()) :: [Tag.t()]
  def list_tags_for_portfolio(portfolio_id) when is_integer(portfolio_id) do
    Repo.all(
      from t in Tag,
        join: pt in PortfolioTag,
        on: pt.tag_id == t.id,
        where: pt.portfolio_id == ^portfolio_id,
        order_by: t.name
    )
  end

  # Private helpers

  defp annotate_tag(nil, _percent), do: nil
  defp annotate_tag(tag, percent), do: Map.put(tag, :target_allocation_percent, percent)

  defp allocation_error_changeset(portfolio, attrs, message \\ "each must be between 0 and 100") do
    Portfolio.changeset(portfolio, attrs)
    |> Ecto.Changeset.add_error(:tag_allocations, message)
  end

  defp validate_percentages_sum(percentages) do
    total = Enum.reduce(percentages, Decimal.new(0), &Decimal.add/2)

    if Decimal.equal?(Decimal.round(total, 2), Decimal.new("100.00")) do
      :ok
    else
      {:error, "must sum to 100 for the selected tags (currently #{total})"}
    end
  end

  defp parse_percentages(tag_allocations) do
    Enum.reduce_while(tag_allocations, {:ok, []}, fn {_tag_id, value}, {:ok, acc} ->
      case parse_decimal(value) do
        {:ok, decimal} -> {:cont, {:ok, [decimal | acc]}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp parse_decimal(nil), do: :error
  defp parse_decimal(""), do: :error
  defp parse_decimal(%Decimal{} = decimal), do: {:ok, decimal}

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> {:ok, decimal}
      _ -> :error
    end
  end

  defp parse_decimal(value) when is_number(value), do: {:ok, Decimal.from_float(value * 1.0)}

  # Helper for string/integer normalization
  defp normalize_tag_id(id) when is_binary(id), do: String.to_integer(id)
  defp normalize_tag_id(id) when is_integer(id), do: id

  # Helper to insert portfolio tags, validating each row's allocation
  defp insert_portfolio_tags(repo, portfolio_id, tag_allocations) do
    Enum.reduce_while(tag_allocations, {:ok, []}, fn {tag_id, percent}, {:ok, acc} ->
      attrs = %{
        portfolio_id: portfolio_id,
        tag_id: normalize_tag_id(tag_id),
        target_allocation_percent: percent
      }

      %PortfolioTag{}
      |> PortfolioTag.changeset(attrs)
      |> repo.insert()
      |> case do
        {:ok, portfolio_tag} -> {:cont, {:ok, [portfolio_tag | acc]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end
end
