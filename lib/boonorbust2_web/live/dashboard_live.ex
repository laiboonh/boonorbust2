defmodule Boonorbust2Web.DashboardLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Dashboard
  alias Boonorbust2.Irr

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :loading, !connected?(socket))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    if socket.assigns.loading do
      {:noreply, socket}
    else
      {:noreply, load_dashboard(socket)}
    end
  end

  defp load_dashboard(socket) do
    %{id: user_id, currency: user_currency} = socket.assigns.current_user

    socket
    |> assign(:loading, false)
    |> assign(Dashboard.load_dashboard_data(user_id, user_currency))
    |> assign_async(:irr, fn -> load_irr(user_id) end)
  end

  defp load_irr(user_id) do
    case Irr.calculate_portfolio_irr(user_id) do
      {:ok, rate} -> {:ok, %{irr: rate}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_irr_percentage(rate) do
    "#{Float.round(rate * 100, 2)}%"
  end
end
