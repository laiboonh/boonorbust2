defmodule Boonorbust2.Messages.Message do
  @moduledoc """
  Schema and changeset functions for messages.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          author: String.t() | nil,
          content: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "messages" do
    field :author, :string
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :author])
    |> validate_required([:content, :author])
  end
end
