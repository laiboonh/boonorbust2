defmodule Boonorbust2Web.DashboardLive do
  use Boonorbust2Web, :live_view

  require Logger

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
    |> assign_async(:benchmark_irr, fn -> load_benchmark_irr(user_id) end)
  end

  defp load_irr(user_id) do
    case Irr.calculate_portfolio_irr(user_id) do
      {:ok, rate} ->
        {:ok, %{irr: rate}}

      {:error, reason} = error ->
        log_irr_unavailable("IRR", user_id, reason)
        error
    end
  end

  defp load_benchmark_irr(user_id) do
    case Irr.calculate_benchmark_irr(user_id) do
      {:ok, rate} ->
        {:ok, %{benchmark_irr: rate}}

      {:error, reason} = error ->
        log_irr_unavailable("Benchmark IRR", user_id, reason)
        error
    end
  end

  # :no_sign_change and :no_time_variance are routine for new or single-day
  # portfolios and are already surfaced to the user as "unavailable" in the
  # UI, so they don't warrant a warning-level log.
  defp log_irr_unavailable(label, user_id, reason)
       when reason in [:no_sign_change, :no_time_variance] do
    Logger.debug("#{label} unavailable for user #{user_id}: #{inspect(reason)}")
  end

  defp log_irr_unavailable(label, user_id, reason) do
    Logger.warning("#{label} unavailable for user #{user_id}: #{inspect(reason)}")
  end

  defp format_irr_percentage(rate) do
    "#{Float.round(rate * 100, 2)}%"
  end

  defp format_irr_delta(delta) do
    percentage = Float.round(delta * 100, 2)
    sign = if percentage >= 0, do: "+", else: ""
    "#{sign}#{percentage}%"
  end
end
