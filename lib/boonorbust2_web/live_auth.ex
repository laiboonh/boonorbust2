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
      admin_emails = Application.get_env(:boonorbust2, :admins, [])
      is_admin = user.email in admin_emails

      {:cont, socket |> assign(:current_user, user) |> assign(:is_admin, is_admin)}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end
end
