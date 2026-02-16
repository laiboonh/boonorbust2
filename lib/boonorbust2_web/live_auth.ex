defmodule Boonorbust2Web.LiveAuth do
  @moduledoc """
  LiveView authentication hook.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Boonorbust2.Accounts
  alias Boonorbust2.Currency

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:require_authenticated_user, _params, session, socket) do
    user_id = session["user_id"]
    user = user_id && Accounts.get_user_by_id(user_id)

    if user do
      admin_emails = Application.get_env(:boonorbust2, :admins, [])
      is_admin = user.email in admin_emails

      socket =
        socket
        |> assign(:current_user, user)
        |> assign(:is_admin, is_admin)
        |> assign(:user_edit_changeset, nil)
        |> assign(:currency_options, Currency.currency_options())
        |> attach_hook(:user_edit_events, :handle_event, &handle_user_edit_event/3)

      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end

  defp handle_user_edit_event("open_user_edit", _params, socket) do
    changeset = Accounts.change_user(socket.assigns.current_user)
    {:halt, assign(socket, :user_edit_changeset, changeset)}
  end

  defp handle_user_edit_event("close_user_edit", _params, socket) do
    {:halt, assign(socket, :user_edit_changeset, nil)}
  end

  defp handle_user_edit_event("save_user", %{"user" => user_params}, socket) do
    case Accounts.update_user(socket.assigns.current_user, user_params) do
      {:ok, updated_user} ->
        {:halt,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:user_edit_changeset, nil)}

      {:error, changeset} ->
        {:halt, assign(socket, :user_edit_changeset, changeset)}
    end
  end

  defp handle_user_edit_event(_event, _params, socket) do
    {:cont, socket}
  end
end
