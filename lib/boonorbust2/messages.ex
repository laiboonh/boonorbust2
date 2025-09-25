defmodule Boonorbust2.Messages do
  @moduledoc """
  Context module for managing messages.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Messages.Message
  alias Boonorbust2.Repo

  def get_all do
    Repo.all(from m in Message, order_by: [desc: m.inserted_at])
  end
end
