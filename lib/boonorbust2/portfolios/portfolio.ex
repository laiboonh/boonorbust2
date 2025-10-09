defmodule Boonorbust2.Portfolios.Portfolio do
  @moduledoc """
  Schema for portfolio.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Accounts.User
  alias Boonorbust2.Portfolios.PortfolioTag

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          portfolio_tags: [PortfolioTag.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "portfolios" do
    field :name, :string
    field :description, :string

    belongs_to :user, User, type: :binary_id
    has_many :portfolio_tags, PortfolioTag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [:name, :description, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:user_id, :name])
  end
end
