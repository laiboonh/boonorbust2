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
          portfolio: Portfolio.t() | Ecto.Association.NotLoaded.t(),
          tag: Tag.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "portfolio_tags" do
    belongs_to :portfolio, Portfolio
    belongs_to :tag, Tag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(portfolio_tag, attrs) do
    portfolio_tag
    |> cast(attrs, [:portfolio_id, :tag_id])
    |> validate_required([:portfolio_id, :tag_id])
    |> unique_constraint([:portfolio_id, :tag_id])
  end
end
