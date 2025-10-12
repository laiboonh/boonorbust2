defmodule Boonorbust2.PortfolioPositions do
  @moduledoc """
  Context module for managing portfolio positions.
  Tracks running average price and quantity on hand for each transaction.
  Each transaction has its own position record showing the state after that transaction.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.PortfolioPositions.PortfolioPosition
  alias Boonorbust2.PortfolioTransactions.PortfolioTransaction
  alias Boonorbust2.RealizedProfits
  alias Boonorbust2.Repo

  @doc """
  Calculates and upserts positions for all transactions of a given asset.

  Creates one position record per transaction, showing the running state after that transaction:
  - For "buy" transactions:
    - Increases quantity_on_hand by the transaction quantity
    - Recalculates average_price using: (average_price * old_quantity + transaction_amount) / (old_quantity + new_quantity)
  - For "sell" transactions:
    - Decreases quantity_on_hand by the transaction quantity
    - Leaves average_price unchanged

  Returns {:ok, count} where count is the number of positions created/updated.
  """
  @spec calculate_and_upsert_positions_for_asset(integer(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, Ecto.Changeset.t()}
  def calculate_and_upsert_positions_for_asset(asset_id, user_id) do
    transactions =
      from(pt in PortfolioTransaction,
        where: pt.asset_id == ^asset_id and pt.user_id == ^user_id,
        order_by: [asc: pt.transaction_date]
      )
      |> Repo.all()

    case transactions do
      [] ->
        delete_positions_for_asset(asset_id)
        {:ok, 0}

      [_ | _] ->
        transactions
        |> calculate_and_upsert_all_positions()
        |> check_results_for_errors()
    end
  end

  @spec check_results_for_errors([{:ok, PortfolioPosition.t()} | {:error, Ecto.Changeset.t()}]) ::
          {:ok, non_neg_integer()} | {:error, Ecto.Changeset.t()}
  defp check_results_for_errors(results) do
    case Enum.find(results, fn {status, _} -> status == :error end) do
      nil -> {:ok, length(results)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec calculate_and_upsert_all_positions([PortfolioTransaction.t()]) ::
          [{:ok, PortfolioPosition.t()} | {:error, Ecto.Changeset.t()}]
  defp calculate_and_upsert_all_positions(transactions) do
    {results, _state} =
      Enum.map_reduce(
        transactions,
        {nil, Decimal.new(0)},
        fn transaction, {avg_price, qty_on_hand} ->
          {new_avg_price, new_qty_on_hand} =
            calculate_new_position(transaction, avg_price, qty_on_hand)

          # Calculate amount_on_hand here
          {:ok, new_amount_on_hand} = Money.mult(new_avg_price, new_qty_on_hand)

          result =
            upsert_position(
              transaction.asset_id,
              new_avg_price,
              new_qty_on_hand,
              new_amount_on_hand,
              transaction.id
            )

          # Calculate and upsert realized profit for sell transactions
          if transaction.action == "sell" && avg_price != nil do
            upsert_realized_profit_for_transaction(transaction, avg_price)
          end

          {result, {new_avg_price, new_qty_on_hand}}
        end
      )

    results
  end

  @spec calculate_new_position(PortfolioTransaction.t(), Money.t() | nil, Decimal.t()) ::
          {Money.t(), Decimal.t()}
  defp calculate_new_position(transaction, avg_price, qty_on_hand) do
    case transaction.action do
      "buy" ->
        new_qty_on_hand = Decimal.add(qty_on_hand, transaction.quantity)

        new_avg_price =
          if Decimal.eq?(qty_on_hand, 0) do
            # First purchase or position was zero
            # Average price per unit = amount / quantity
            {:ok, price_per_unit} = Money.div(transaction.amount, transaction.quantity)
            price_per_unit
          else
            # Calculate new average: (avg_price * old_qty + transaction_amount) / (old_qty + new_qty)
            {:ok, old_position_value} = Money.mult(avg_price, qty_on_hand)
            {:ok, new_position_value} = Money.add(old_position_value, transaction.amount)
            {:ok, new_avg} = Money.div(new_position_value, new_qty_on_hand)
            new_avg
          end

        {new_avg_price, new_qty_on_hand}

      "sell" ->
        # Cannot sell without an existing position (avg_price would be nil)
        if avg_price == nil do
          raise ArgumentError,
                "Cannot sell asset without a prior buy transaction. Transaction ID: #{transaction.id}"
        end

        new_qty_on_hand = Decimal.sub(qty_on_hand, transaction.quantity)

        # Check for overselling (selling more than available)
        if Decimal.lt?(new_qty_on_hand, 0) do
          raise ArgumentError,
                "Cannot sell more than quantity on hand. Available: #{qty_on_hand}, Attempted to sell: #{transaction.quantity}, Transaction ID: #{transaction.id}"
        end

        {avg_price, new_qty_on_hand}
    end
  end

  @spec upsert_position(integer(), Money.t(), Decimal.t(), Money.t(), integer()) ::
          {:ok, PortfolioPosition.t()} | {:error, Ecto.Changeset.t()}
  defp upsert_position(asset_id, average_price, quantity_on_hand, amount_on_hand, transaction_id) do
    # Get user_id from the transaction
    transaction = Repo.get!(PortfolioTransaction, transaction_id)

    attrs = %{
      user_id: transaction.user_id,
      asset_id: asset_id,
      average_price: average_price,
      quantity_on_hand: quantity_on_hand,
      amount_on_hand: amount_on_hand,
      portfolio_transaction_id: transaction_id
    }

    %PortfolioPosition{}
    |> PortfolioPosition.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :portfolio_transaction_id
    )
  end

  @spec delete_positions_for_asset(integer()) :: :ok
  defp delete_positions_for_asset(asset_id) do
    from(pp in PortfolioPosition, where: pp.asset_id == ^asset_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Gets the latest (most recent) position for a given asset.
  This represents the current state of the position after all transactions.
  """
  @spec get_latest_position_for_asset(integer(), String.t()) :: PortfolioPosition.t() | nil
  def get_latest_position_for_asset(asset_id, user_id) do
    from(pp in PortfolioPosition,
      join: pt in assoc(pp, :portfolio_transaction),
      where: pp.asset_id == ^asset_id and pp.user_id == ^user_id,
      order_by: [desc: pt.transaction_date, desc: pp.id],
      limit: 1,
      preload: [:asset, :portfolio_transaction]
    )
    |> Repo.one()
  end

  @doc """
  Gets all positions for a given asset, ordered by transaction date descending.
  """
  @spec get_positions_for_asset(integer(), String.t()) :: [PortfolioPosition.t()]
  def get_positions_for_asset(asset_id, user_id) do
    from(pp in PortfolioPosition,
      join: pt in assoc(pp, :portfolio_transaction),
      where: pp.asset_id == ^asset_id and pp.user_id == ^user_id,
      order_by: [desc: pt.transaction_date, desc: pp.id],
      preload: [:asset, :portfolio_transaction]
    )
    |> Repo.all()
  end

  @doc """
  Lists the latest position for each asset based on transaction date.
  Supports filtering by asset name or tag name.
  """
  @spec list_latest_positions(String.t(), String.t() | nil) :: [PortfolioPosition.t()]
  def list_latest_positions(user_id, filter \\ nil) do
    # Get the latest position for each asset based on transaction date
    latest_positions_subquery =
      from(pp in PortfolioPosition,
        join: pt in assoc(pp, :portfolio_transaction),
        where: pp.user_id == ^user_id,
        group_by: pp.asset_id,
        select: %{
          asset_id: pp.asset_id,
          max_transaction_date: max(pt.transaction_date),
          max_id: max(pp.id)
        }
      )

    query =
      from(pp in PortfolioPosition,
        join: pt in assoc(pp, :portfolio_transaction),
        join: a in assoc(pp, :asset),
        join: lp in subquery(latest_positions_subquery),
        on: pp.asset_id == lp.asset_id and pt.transaction_date == lp.max_transaction_date,
        where: pp.user_id == ^user_id,
        order_by: [desc: pt.transaction_date, desc: pp.id],
        distinct: pp.asset_id,
        preload: [:asset, :portfolio_transaction]
      )

    query
    |> apply_filter(filter, user_id)
    |> Repo.all()
  end

  @spec apply_filter(Ecto.Query.t(), String.t() | nil, String.t()) :: Ecto.Query.t()
  defp apply_filter(query, nil, _user_id), do: query
  defp apply_filter(query, "", _user_id), do: query

  defp apply_filter(query, filter, user_id) when is_binary(filter) do
    # First check if the filter matches a tag name
    case Boonorbust2.Tags.get_tag_by_name(filter, user_id) do
      nil ->
        # Not a tag, filter by asset name
        apply_asset_name_filter(query, filter)

      tag ->
        # It's a tag, get all asset IDs for this tag
        asset_ids = Boonorbust2.Tags.list_assets_for_tag(tag.id)

        if Enum.empty?(asset_ids) do
          # No assets with this tag, return empty result
          from [pp, pt, a, lp] in query, where: false
        else
          from [pp, pt, a, lp] in query,
            where: a.id in ^asset_ids
        end
    end
  end

  @spec apply_asset_name_filter(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  defp apply_asset_name_filter(query, filter) do
    filter_pattern = "%#{filter}%"

    from [pp, pt, a, lp] in query,
      where: ilike(a.name, ^filter_pattern)
  end

  @doc """
  Returns a list of asset IDs where ANY user has positions with quantity on hand > 0.
  Used to determine which assets are currently held and need price updates.

  For each user-asset combination, checks the latest position (by transaction date).
  If that latest position has quantity_on_hand > 0, includes the asset_id.
  """
  @spec get_asset_ids_with_holdings() :: [integer()]
  def get_asset_ids_with_holdings do
    # Get the latest position for each user-asset combination
    latest_positions_subquery =
      from(pp in PortfolioPosition,
        join: pt in assoc(pp, :portfolio_transaction),
        group_by: [pp.user_id, pp.asset_id],
        select: %{
          user_id: pp.user_id,
          asset_id: pp.asset_id,
          max_transaction_date: max(pt.transaction_date),
          max_id: max(pp.id)
        }
      )

    # Get assets where the latest position for any user has quantity > 0
    from(pp in PortfolioPosition,
      join: pt in assoc(pp, :portfolio_transaction),
      join: lp in subquery(latest_positions_subquery),
      on:
        pp.user_id == lp.user_id and pp.asset_id == lp.asset_id and
          pt.transaction_date == lp.max_transaction_date,
      where: pp.quantity_on_hand > 0,
      distinct: pp.asset_id,
      select: pp.asset_id
    )
    |> Repo.all()
  end

  # Calculates and upserts realized profit for a sell transaction.
  # Realized profit = (sell_price - avg_cost_price) * quantity
  @spec upsert_realized_profit_for_transaction(PortfolioTransaction.t(), Money.t()) ::
          {:ok, RealizedProfits.RealizedProfit.t()} | {:error, Ecto.Changeset.t()}
  defp upsert_realized_profit_for_transaction(transaction, avg_price) do
    # Calculate profit per unit: sell_price - avg_cost_price
    {:ok, profit_per_unit} = Money.sub(transaction.price, avg_price)

    # Calculate total realized profit: profit_per_unit * quantity
    {:ok, realized_profit_amount} = Money.mult(profit_per_unit, transaction.quantity)

    attrs = %{
      user_id: transaction.user_id,
      asset_id: transaction.asset_id,
      portfolio_transaction_id: transaction.id,
      amount: realized_profit_amount
    }

    RealizedProfits.upsert_realized_profit(attrs)
  end
end
