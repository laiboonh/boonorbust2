defmodule Boonorbust2.Messages.Message do
  @moduledoc """
  Schema and changeset functions for messages.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :author, :string
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :author])
    |> validate_required([:content, :author])
  end
end
