defmodule Boonorbust2Web.DashboardLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Dashboard
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.Portfolios
  alias Boonorbust2.PortfolioSnapshots
  alias Boonorbust2.RealizedProfits
  alias Boonorbust2.Tags

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

    # Fetch raw data from contexts
    positions = PortfolioPositions.list_latest_positions(user_id, nil)
    realized_profits_by_asset = RealizedProfits.get_totals_by_asset(user_id)
    all_tags = Tags.list_tags(user_id)
    portfolios = Portfolios.list_portfolios(user_id)
    upcoming_dividends = RealizedProfits.list_upcoming_dividend_payments(user_id)
    recent_dividends = RealizedProfits.list_recent_dividend_payments(user_id)

    # Delegate all business logic to Dashboard context
    enriched_positions =
      Dashboard.enrich_positions_for_dashboard(positions, user_id, user_currency)

    converted_realized_profits =
      Dashboard.convert_realized_profits_by_asset(realized_profits_by_asset, user_currency)

    total_portfolio_value =
      PortfolioPositions.calculate_total_portfolio_value(enriched_positions, user_currency)

    # Save snapshot before fetching so today's value is always included in the chart
    PortfolioPositions.save_portfolio_snapshot(user_id, total_portfolio_value)
    portfolio_snapshots = PortfolioSnapshots.list_snapshots(user_id, days: 90)

    # Calculate chart data
    tag_chart_data = Dashboard.calculate_tag_chart_data(enriched_positions)

    investment_allocation_data =
      Dashboard.calculate_investment_allocation_data(enriched_positions, total_portfolio_value)

    dividend_chart_data = Dashboard.prepare_dividend_chart_data(user_id, user_currency)

    # Enrich portfolios
    portfolios_with_data =
      Dashboard.enrich_portfolios_with_chart_data(portfolios, enriched_positions)

    # Convert dividends
    upcoming_dividends_converted =
      Dashboard.convert_dividends_to_user_currency(upcoming_dividends, user_currency)

    recent_dividends_converted =
      Dashboard.convert_dividends_to_user_currency(recent_dividends, user_currency)

    socket
    |> assign(:loading, false)
    |> assign(:positions, enriched_positions)
    |> assign(:realized_profits_by_asset, realized_profits_by_asset)
    |> assign(:converted_realized_profits_by_asset, converted_realized_profits)
    |> assign(:all_tags, all_tags)
    |> assign(:tag_chart_data, tag_chart_data)
    |> assign(:portfolios, portfolios_with_data)
    |> assign(:user_currency, user_currency)
    |> assign(:portfolio_snapshots, portfolio_snapshots)
    |> assign(:dividend_chart_data, dividend_chart_data)
    |> assign(:upcoming_dividends, upcoming_dividends_converted)
    |> assign(:recent_dividends, recent_dividends_converted)
    |> assign(:investment_allocation_chart_data, investment_allocation_data)
  end
end
