defmodule Boonorbust2.PortfolioSnapshots.PortfolioSnapshot do
  @moduledoc """
  Schema and changeset functions for portfolio snapshots.

  Portfolio snapshots store the total portfolio value for a user on a given date.
  The combination of user_id and snapshot_date is unique.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Accounts.User

  @derive {Jason.Encoder, only: [:snapshot_date, :total_value]}

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: Ecto.UUID.t() | nil,
          user: User.t() | nil,
          snapshot_date: Date.t() | nil,
          total_value: Money.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "portfolio_snapshots" do
    belongs_to :user, User, type: :binary_id
    field :snapshot_date, :date
    field :total_value, Money.Ecto.Composite.Type

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(portfolio_snapshot, attrs) do
    portfolio_snapshot
    |> cast(attrs, [:user_id, :snapshot_date, :total_value])
    |> validate_required([:user_id, :snapshot_date, :total_value])
    |> validate_money(:total_value)
    |> unique_constraint([:user_id, :snapshot_date],
      name: :portfolio_snapshots_user_id_snapshot_date_index
    )
    |> foreign_key_constraint(:user_id)
  end

  defp validate_money(changeset, field) do
    case get_field(changeset, field) do
      %Money{} ->
        changeset

      nil ->
        changeset

      _ ->
        add_error(changeset, field, "must be a valid Money amount")
    end
  end
end
