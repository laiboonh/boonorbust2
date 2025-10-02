defmodule Boonorbust2.PortfolioPositions do
  @moduledoc """
  Context module for managing portfolio positions.
  Tracks running average price and quantity on hand for each transaction.
  Each transaction has its own position record showing the state after that transaction.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.PortfolioPositions.PortfolioPosition
  alias Boonorbust2.PortfolioTransactions.PortfolioTransaction
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
  @spec calculate_and_upsert_positions_for_asset(integer()) ::
          {:ok, non_neg_integer()} | {:error, Ecto.Changeset.t()}
  def calculate_and_upsert_positions_for_asset(asset_id) do
    transactions =
      from(pt in PortfolioTransaction,
        where: pt.asset_id == ^asset_id,
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

          result =
            upsert_position(
              transaction.asset_id,
              new_avg_price,
              new_qty_on_hand,
              transaction.id
            )

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

  @spec upsert_position(integer(), Money.t(), Decimal.t(), integer()) ::
          {:ok, PortfolioPosition.t()} | {:error, Ecto.Changeset.t()}
  defp upsert_position(asset_id, average_price, quantity_on_hand, transaction_id) do
    attrs = %{
      asset_id: asset_id,
      average_price: average_price,
      quantity_on_hand: quantity_on_hand,
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
  @spec get_latest_position_for_asset(integer()) :: PortfolioPosition.t() | nil
  def get_latest_position_for_asset(asset_id) do
    from(pp in PortfolioPosition,
      join: pt in assoc(pp, :portfolio_transaction),
      where: pp.asset_id == ^asset_id,
      order_by: [desc: pt.transaction_date, desc: pp.id],
      limit: 1,
      preload: [:asset, :portfolio_transaction]
    )
    |> Repo.one()
  end

  @doc """
  Gets all positions for a given asset, ordered by transaction date descending.
  """
  @spec get_positions_for_asset(integer()) :: [PortfolioPosition.t()]
  def get_positions_for_asset(asset_id) do
    from(pp in PortfolioPosition,
      join: pt in assoc(pp, :portfolio_transaction),
      where: pp.asset_id == ^asset_id,
      order_by: [desc: pt.transaction_date, desc: pp.id],
      preload: [:asset, :portfolio_transaction]
    )
    |> Repo.all()
  end

  @doc """
  Lists the latest position for each asset.
  """
  @spec list_latest_positions() :: [PortfolioPosition.t()]
  def list_latest_positions do
    # Get the latest position for each asset using a subquery
    latest_positions_subquery =
      from(pp in PortfolioPosition,
        group_by: pp.asset_id,
        select: %{asset_id: pp.asset_id, max_updated_at: max(pp.updated_at)}
      )

    from(pp in PortfolioPosition,
      join: lp in subquery(latest_positions_subquery),
      on: pp.asset_id == lp.asset_id and pp.updated_at == lp.max_updated_at,
      order_by: [desc: pp.updated_at],
      preload: [:asset, :portfolio_transaction]
    )
    |> Repo.all()
  end
end
