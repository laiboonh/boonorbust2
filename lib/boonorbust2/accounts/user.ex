defmodule Boonorbust2.Accounts.User do
  @moduledoc """
  Schema and changeset functions for user accounts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Currency
  alias Boonorbust2.Tags.AssetTag

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          uid: String.t() | nil,
          provider: String.t() | nil,
          email: String.t() | nil,
          currency: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :name, :string
    field :uid, :string
    field :provider, :string
    field :email, :string
    field :currency, :string, default: "SGD"

    has_many :asset_tags, AssetTag

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :provider, :uid, :currency])
    |> validate_required([:email, :name, :provider, :uid])
    |> validate_inclusion(:currency, Currency.supported_currencies())
  end
end
