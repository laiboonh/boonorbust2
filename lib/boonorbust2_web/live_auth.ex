defmodule Boonorbust2Web.LiveAuth do
  @moduledoc """
  LiveView authentication hook.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Boonorbust2.Accounts

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:require_authenticated_user, _params, session, socket) do
    user_id = session["user_id"]
    user = user_id && Accounts.get_user_by_id(user_id)

    if user do
      {:cont, assign(socket, :current_user, user)}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end
end
