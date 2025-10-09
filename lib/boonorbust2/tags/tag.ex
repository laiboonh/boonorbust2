defmodule Boonorbust2.Tags.Tag do
  @moduledoc """
  Schema and changeset functions for tags.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Accounts.User
  alias Boonorbust2.Portfolios.PortfolioTag
  alias Boonorbust2.Tags.AssetTag

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          color: String.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "tags" do
    field :name, :string
    field :color, :string

    belongs_to :user, User, type: :binary_id

    has_many :asset_tags, AssetTag
    has_many :portfolio_tags, PortfolioTag

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color, :user_id])
    |> validate_required([:name, :user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :name])
  end
end
