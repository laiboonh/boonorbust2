defmodule Boonorbust2.Portfolios.PortfolioTag do
  @moduledoc """
  Join table schema for portfolio tags.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Portfolios.Portfolio
  alias Boonorbust2.Tags.Tag

  @type t :: %__MODULE__{
          id: integer(),
          portfolio_id: integer(),
          tag_id: integer(),
          target_allocation_percent: Decimal.t() | nil,
          portfolio: Portfolio.t() | Ecto.Association.NotLoaded.t(),
          tag: Tag.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "portfolio_tags" do
    belongs_to :portfolio, Portfolio
    belongs_to :tag, Tag
    field :target_allocation_percent, :decimal

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(portfolio_tag, attrs) do
    portfolio_tag
    |> cast(attrs, [:portfolio_id, :tag_id, :target_allocation_percent])
    |> validate_required([:portfolio_id, :tag_id, :target_allocation_percent])
    |> validate_number(:target_allocation_percent,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> unique_constraint([:portfolio_id, :tag_id])
  end
end
