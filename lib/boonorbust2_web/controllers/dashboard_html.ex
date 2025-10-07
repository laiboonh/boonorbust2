defmodule Boonorbust2Web.DashboardHTML do
  use Boonorbust2Web, :html

  def index(assigns) do
    ~H"""
    <.tab_content class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <h1 class="text-2xl font-bold text-gray-900 mb-6">Portfolio Dashboard</h1>

          <%= if Enum.empty?(@positions) do %>
            <div class="bg-white rounded-lg shadow p-8 text-center">
              <p class="text-gray-500 mb-4">No portfolio positions yet.</p>
              <p class="text-sm text-gray-400">
                Add transactions to see your portfolio positions here.
              </p>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for position <- @positions do %>
                <.position_card
                  position={position}
                  realized_profit={
                    Map.get(
                      @realized_profits_by_asset,
                      position.asset_id,
                      Money.new(position.amount_on_hand.currency, 0)
                    )
                  }
                />
              <% end %>
            </div>
          <% end %>
        </div>

        <.tab_bar current_tab="dashboard">
          <:tab navigate={~p"/dashboard"} name="dashboard" icon="hero-home">
            Dashboard
          </:tab>
          <:tab navigate={~p"/assets"} name="assets" icon="hero-chart-bar">
            Assets
          </:tab>
          <:tab navigate={~p"/portfolio_transactions"} name="portfolio" icon="hero-document-text">
            Transactions
          </:tab>
        </.tab_bar>
      </div>
    </.tab_content>
    """
  end

  def position_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex justify-between items-start mb-4">
        <div class="flex-1">
          <h3 class="text-lg font-semibold text-gray-900">{@position.asset.name}</h3>
        </div>
        <div class="flex items-center gap-2">
          <button
            hx-get={~p"/dashboard/positions/#{@position.asset.id}"}
            hx-target={"#positions-modal-#{@position.asset.id}"}
            hx-swap="innerHTML"
            hx-on::before-request={"document.getElementById('positions-icon-#{@position.asset.id}').classList.add('hidden'); document.getElementById('positions-spinner-#{@position.asset.id}').classList.remove('hidden');"}
            hx-on::after-request={"document.getElementById('positions-spinner-#{@position.asset.id}').classList.add('hidden'); document.getElementById('positions-icon-#{@position.asset.id}').classList.remove('hidden');"}
            onclick={"document.getElementById('positions-modal-#{@position.asset.id}').classList.remove('hidden')"}
            class="text-blue-600 hover:text-blue-800"
            title="View positions"
          >
            <svg
              id={"positions-icon-#{@position.asset.id}"}
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
              >
              </path>
            </svg>
            <svg
              id={"positions-spinner-#{@position.asset.id}"}
              class="hidden w-5 h-5 animate-spin text-blue-600"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
              </circle>
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              >
              </path>
            </svg>
          </button>
          <button
            hx-get={~p"/dashboard/realized_profits/#{@position.asset.id}"}
            hx-target={"#realized-profits-modal-#{@position.asset.id}"}
            hx-swap="innerHTML"
            hx-on::before-request={"document.getElementById('profits-icon-#{@position.asset.id}').classList.add('hidden'); document.getElementById('profits-spinner-#{@position.asset.id}').classList.remove('hidden');"}
            hx-on::after-request={"document.getElementById('profits-spinner-#{@position.asset.id}').classList.add('hidden'); document.getElementById('profits-icon-#{@position.asset.id}').classList.remove('hidden');"}
            onclick={"document.getElementById('realized-profits-modal-#{@position.asset.id}').classList.remove('hidden')"}
            class="text-emerald-600 hover:text-emerald-800"
            title="View realized profits"
          >
            <svg
              id={"profits-icon-#{@position.asset.id}"}
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              >
              </path>
            </svg>
            <svg
              id={"profits-spinner-#{@position.asset.id}"}
              class="hidden w-5 h-5 animate-spin text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
              </circle>
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              >
              </path>
            </svg>
          </button>
          <span class="bg-emerald-100 text-emerald-800 text-xs font-medium px-2.5 py-0.5 rounded">
            {String.upcase(@position.portfolio_transaction.action)}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <p class="text-sm text-gray-500">Quantity</p>
          <p class="text-xl font-bold text-gray-900">
            {Decimal.to_string(@position.quantity_on_hand)}
          </p>
        </div>
        <div>
          <p class="text-sm text-gray-500">Avg Price</p>
          <p class="text-xl font-bold text-emerald-600">
            {Money.to_string!(@position.average_price)}
          </p>
        </div>
      </div>

      <div class="mt-4 pt-4 border-t border-gray-200">
        <div class="flex justify-between items-center mb-2">
          <p class="text-sm text-gray-500">Total Cost</p>
          <p class="text-xl font-bold text-gray-900">
            {Money.to_string!(@position.amount_on_hand)}
          </p>
        </div>
        <%= if @position.asset.price do %>
          <% total_value =
            Money.new!(
              Decimal.mult(@position.quantity_on_hand, @position.asset.price),
              @position.amount_on_hand.currency
            )

          {:ok, unrealized_profit} = Money.sub(total_value, @position.amount_on_hand) %>
          <div class="flex justify-between items-center">
            <p class="text-sm text-gray-500">Total Value</p>
            <p class="text-2xl font-bold text-emerald-600">
              {Money.to_string!(total_value)}
            </p>
          </div>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-sm text-gray-500">Unrealized Profit</p>
            <p class={[
              "text-lg font-bold",
              if(Decimal.positive?(unrealized_profit.amount),
                do: "text-emerald-600",
                else: "text-red-600"
              )
            ]}>
              {Money.to_string!(unrealized_profit)}
            </p>
          </div>
        <% end %>
        <%= if !Decimal.equal?(@realized_profit.amount, 0) do %>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-sm text-gray-500">Realized Profit</p>
            <p class={[
              "text-lg font-bold",
              if(Decimal.positive?(@realized_profit.amount),
                do: "text-emerald-600",
                else: "text-red-600"
              )
            ]}>
              {Money.to_string!(@realized_profit)}
            </p>
          </div>
        <% end %>
      </div>

      <p class="text-xs text-gray-400 mt-4">
        Last updated: {Calendar.strftime(
          @position.portfolio_transaction.transaction_date,
          "%B %d, %Y"
        )}
      </p>
      
    <!-- Positions Modal -->
      <div
        id={"positions-modal-#{@position.asset.id}"}
        class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        onclick={"if(event.target.id === 'positions-modal-#{@position.asset.id}') { this.classList.add('hidden'); document.getElementById('positions-spinner-#{@position.asset.id}').classList.add('hidden'); document.getElementById('positions-icon-#{@position.asset.id}').classList.remove('hidden'); }"}
      >
      </div>
      
    <!-- Realized Profits Modal -->
      <div
        id={"realized-profits-modal-#{@position.asset.id}"}
        class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        onclick={"if(event.target.id === 'realized-profits-modal-#{@position.asset.id}') { this.classList.add('hidden'); document.getElementById('profits-spinner-#{@position.asset.id}').classList.add('hidden'); document.getElementById('profits-icon-#{@position.asset.id}').classList.remove('hidden'); }"}
      >
      </div>
    </div>
    """
  end

  def positions_modal_content(assigns) do
    ~H"""
    <div class="relative p-2 sm:p-4">
      <div class="bg-white rounded-lg shadow-xl max-w-full sm:max-w-4xl mx-auto mt-4 sm:mt-20">
        <div class="flex justify-between items-center p-3 sm:p-6 border-b">
          <h2 class="text-lg sm:text-2xl font-bold text-gray-900">
            Portfolio Positions - {@asset.name}
          </h2>
          <button
            onclick={"document.getElementById('positions-modal-#{@asset.id}').classList.add('hidden'); document.getElementById('positions-spinner-#{@asset.id}').classList.add('hidden'); document.getElementById('positions-icon-#{@asset.id}').classList.remove('hidden');"}
            class="text-gray-400 hover:text-gray-600 ml-2"
          >
            <svg class="w-5 h-5 sm:w-6 sm:h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              >
              </path>
            </svg>
          </button>
        </div>

        <div class="p-3 sm:p-6">
          <%= if Enum.empty?(@positions) do %>
            <p class="text-gray-500 text-center py-8">
              No positions found for this asset.
            </p>
          <% else %>
            <div class="overflow-x-auto -mx-3 sm:mx-0">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Date
                    </th>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Type
                    </th>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Avg Price
                    </th>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Qty
                    </th>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Amount
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for position <- @positions do %>
                    <tr>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-gray-900">
                        <span class="hidden sm:inline">
                          {Calendar.strftime(
                            position.portfolio_transaction.transaction_date,
                            "%B %d, %Y"
                          )}
                        </span>
                        <span class="sm:hidden">
                          {Calendar.strftime(
                            position.portfolio_transaction.transaction_date,
                            "%m/%d/%y"
                          )}
                        </span>
                      </td>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm">
                        <span class={
                          if position.portfolio_transaction.action == "buy",
                            do: "text-emerald-600 font-medium",
                            else: "text-red-600 font-medium"
                        }>
                          {String.upcase(position.portfolio_transaction.action)}
                        </span>
                      </td>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-right font-medium text-gray-900">
                        {Money.to_string!(position.average_price)}
                      </td>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-right text-gray-900">
                        {Decimal.to_string(position.quantity_on_hand)}
                      </td>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-right font-semibold text-emerald-600">
                        {Money.to_string!(position.amount_on_hand)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def realized_profits_modal_content(assigns) do
    ~H"""
    <div class="relative p-2 sm:p-4">
      <div class="bg-white rounded-lg shadow-xl max-w-full sm:max-w-4xl mx-auto mt-4 sm:mt-20">
        <div class="flex justify-between items-center p-3 sm:p-6 border-b">
          <h2 class="text-lg sm:text-2xl font-bold text-gray-900">
            Realized Profits - {@asset.name}
          </h2>
          <button
            onclick={"document.getElementById('realized-profits-modal-#{@asset.id}').classList.add('hidden'); document.getElementById('profits-spinner-#{@asset.id}').classList.add('hidden'); document.getElementById('profits-icon-#{@asset.id}').classList.remove('hidden');"}
            class="text-gray-400 hover:text-gray-600 ml-2"
          >
            <svg class="w-5 h-5 sm:w-6 sm:h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              >
              </path>
            </svg>
          </button>
        </div>

        <div class="p-3 sm:p-6">
          <%= if Enum.empty?(@realized_profits) do %>
            <p class="text-gray-500 text-center py-8">
              No realized profits found for this asset.
            </p>
          <% else %>
            <div class="overflow-x-auto -mx-3 sm:mx-0">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Date
                    </th>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Sell Price
                    </th>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Qty Sold
                    </th>
                    <th class="px-2 sm:px-6 py-2 sm:py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Profit/Loss
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for rp <- @realized_profits do %>
                    <tr>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-gray-900">
                        <span class="hidden sm:inline">
                          {Calendar.strftime(
                            rp.portfolio_transaction.transaction_date,
                            "%B %d, %Y"
                          )}
                        </span>
                        <span class="sm:hidden">
                          {Calendar.strftime(
                            rp.portfolio_transaction.transaction_date,
                            "%m/%d/%y"
                          )}
                        </span>
                      </td>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-right font-medium text-gray-900">
                        {Money.to_string!(rp.portfolio_transaction.price)}
                      </td>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-right text-gray-900">
                        {Decimal.to_string(rp.portfolio_transaction.quantity)}
                      </td>
                      <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm text-right font-semibold">
                        <span class={
                          if Decimal.positive?(rp.amount.amount),
                            do: "text-emerald-600",
                            else: "text-red-600"
                        }>
                          {Money.to_string!(rp.amount)}
                        </span>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
