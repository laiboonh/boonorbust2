defmodule Boonorbust2Web.UserLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Accounts
  alias Boonorbust2.Currency

  @impl true
  def mount(%{"return_to" => return_to}, _session, socket) do
    {:ok, init_socket(socket, return_to)}
  end

  def mount(_params, _session, socket) do
    {:ok, init_socket(socket, ~p"/dashboard")}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, _updated_user} ->
        {:noreply, push_navigate(socket, to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, form_errors: changeset, changeset: changeset)}
    end
  end

  defp init_socket(socket, return_to) do
    user = socket.assigns.current_user
    changeset = Accounts.change_user(user)

    socket
    |> assign(:user, user)
    |> assign(:changeset, changeset)
    |> assign(:form_errors, nil)
    |> assign(:currency_options, Currency.currency_options())
    |> assign(:return_to, return_to)
  end
end
