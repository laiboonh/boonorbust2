defmodule Boonorbust2Web.PositionsLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Assets
  alias Boonorbust2.Dashboard
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.RealizedProfits

  @impl true
  def mount(_params, _session, socket) do
    %{id: user_id, currency: user_currency} = socket.assigns.current_user

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:user_currency, user_currency)
      |> assign(:filter, "")
      |> assign(:positions_modal, nil)
      |> assign(:realized_profits_modal, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, reload_data(socket)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    socket =
      socket
      |> assign(:filter, filter)
      |> reload_data()

    {:noreply, socket}
  end

  def handle_event("clear_filter", _params, socket) do
    socket =
      socket
      |> assign(:filter, "")
      |> reload_data()

    {:noreply, socket}
  end

  def handle_event("show_positions", %{"id" => asset_id}, socket) do
    asset = Assets.get_asset!(asset_id)
    positions = PortfolioPositions.get_positions_for_asset(asset.id, socket.assigns.user_id)

    {:noreply, assign(socket, positions_modal: %{asset: asset, positions: positions})}
  end

  def handle_event("close_positions_modal", _params, socket) do
    {:noreply, assign(socket, positions_modal: nil)}
  end

  def handle_event("show_realized_profits", %{"id" => asset_id}, socket) do
    asset = Assets.get_asset!(asset_id)

    realized_profits =
      RealizedProfits.list_realized_profits_by_asset(asset.id, socket.assigns.user_id)

    total = RealizedProfits.calculate_total(realized_profits)

    {:noreply,
     assign(socket,
       realized_profits_modal: %{
         asset: asset,
         realized_profits: realized_profits,
         total: total
       }
     )}
  end

  def handle_event("close_realized_profits_modal", _params, socket) do
    {:noreply, assign(socket, realized_profits_modal: nil)}
  end

  def position_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-4">
      <div class="flex justify-between items-start mb-3">
        <div class="flex-1">
          <h3 class="text-base font-semibold text-gray-900">{@position.asset.name}</h3>
        </div>
        <div class="flex items-center gap-1.5">
          <button
            phx-click="show_positions"
            phx-value-id={@position.asset.id}
            class="text-blue-600 hover:text-blue-800"
            title="View positions"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
              >
              </path>
            </svg>
          </button>
          <button
            phx-click="show_realized_profits"
            phx-value-id={@position.asset.id}
            class="text-emerald-600 hover:text-emerald-800"
            title="View realized profits"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              >
              </path>
            </svg>
          </button>
          <span class="bg-emerald-100 text-emerald-800 text-xs font-medium px-2.5 py-0.5 rounded">
            {String.upcase(@position.portfolio_transaction.action)}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <p class="text-xs text-gray-500">Quantity</p>
          <p class="text-lg font-bold text-gray-900">
            {Decimal.to_string(@position.quantity_on_hand)}
          </p>
        </div>
        <div>
          <p class="text-xs text-gray-500">Avg Price</p>
          <p class="text-lg font-bold text-emerald-600">
            {Money.to_string!(@position.average_price, fractional_digits: 4)}
          </p>
        </div>
      </div>

      <div class="mt-3 pt-3 border-t border-gray-200">
        <% converted_cost = Map.get(@position, :converted_total_cost)
        show_converted_cost = Map.get(@position, :show_converted_cost, false) %>
        <div class="flex justify-between items-center mb-2">
          <p class="text-xs text-gray-500">Total Cost</p>
          <div class="text-right">
            <%= if show_converted_cost do %>
              <p class="text-lg font-bold text-gray-900">
                {Money.to_string!(converted_cost)}
              </p>
              <p class="text-xs text-gray-400">
                ({Money.to_string!(@position.amount_on_hand)})
              </p>
            <% else %>
              <p class="text-lg font-bold text-gray-900">
                {Money.to_string!(@position.amount_on_hand)}
              </p>
            <% end %>
          </div>
        </div>
        <%= if @position.asset.price do %>
          <% total_value = @position.total_value
          unrealized_profit = @position.unrealized_profit
          converted_value = Map.get(@position, :converted_total_value)
          show_converted = Map.get(@position, :show_converted_value, false) %>
          <div class="flex justify-between items-center">
            <p class="text-xs text-gray-500">Total Value</p>
            <div class="text-right">
              <%= if show_converted do %>
                <p class="text-xl font-bold text-emerald-600">
                  {Money.to_string!(converted_value)}
                </p>
                <p class="text-xs text-gray-400">
                  ({Money.to_string!(total_value)})
                </p>
              <% else %>
                <p class="text-xl font-bold text-emerald-600">
                  {Money.to_string!(total_value)}
                </p>
              <% end %>
            </div>
          </div>
          <% converted_unrealized_profit = Map.get(@position, :converted_unrealized_profit)
          show_converted_unrealized = Map.get(@position, :show_converted_unrealized, false) %>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-xs text-gray-500">Unrealized Profit</p>
            <div class="text-right">
              <%= if show_converted_unrealized do %>
                <p class={[
                  "text-base font-bold",
                  if(Decimal.positive?(converted_unrealized_profit.amount),
                    do: "text-emerald-600",
                    else: "text-red-600"
                  )
                ]}>
                  {Money.to_string!(converted_unrealized_profit)}
                </p>
                <p class="text-xs text-gray-400">
                  ({Money.to_string!(unrealized_profit)})
                </p>
              <% else %>
                <p class={[
                  "text-base font-bold",
                  if(Decimal.positive?(unrealized_profit.amount),
                    do: "text-emerald-600",
                    else: "text-red-600"
                  )
                ]}>
                  {Money.to_string!(unrealized_profit)}
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
        <%= if !Decimal.equal?(@capital_gains.amount, 0) do %>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-xs text-gray-500">Capital Gains</p>
            <div class="text-right">
              <p class={[
                "text-base font-bold",
                if(Decimal.positive?(@capital_gains.amount),
                  do: "text-emerald-600",
                  else: "text-red-600"
                )
              ]}>
                {Money.to_string!(@capital_gains)}
              </p>
            </div>
          </div>
        <% end %>
        <%= if !Decimal.equal?(@dividend_income.amount, 0) do %>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-xs text-gray-500">Dividend Income</p>
            <div class="text-right">
              <p class="text-base font-bold text-emerald-600">
                {Money.to_string!(@dividend_income)}
              </p>
            </div>
          </div>
        <% end %>
      </div>

      <p class="text-xs text-gray-400 mt-3">
        Last updated: {Calendar.strftime(
          @position.portfolio_transaction.transaction_date,
          "%B %d, %Y"
        )}
      </p>
    </div>
    """
  end

  defp reload_data(socket) do
    %{user_id: user_id, user_currency: user_currency, filter: filter} = socket.assigns
    assign(socket, Dashboard.load_positions_data(user_id, user_currency, filter))
  end
end
