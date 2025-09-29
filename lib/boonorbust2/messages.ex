defmodule Boonorbust2.Messages do
  @moduledoc """
  Context module for managing messages.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Messages.Message
  alias Boonorbust2.Repo

  @spec get_all() :: [Message.t()]
  def get_all do
    Helper.do_retry(
      fn -> Repo.all(from m in Message, order_by: [desc: m.inserted_at]) end,
      [DBConnection.ConnectionError]
    )
  end
end
