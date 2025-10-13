defmodule Boonorbust2Web.AssetHTML do
  use Boonorbust2Web, :html

  alias Boonorbust2.Currency

  def index(assigns) do
    ~H"""
    <.tab_content class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="flex gap-3 mb-6">
            <button
              onclick="document.getElementById('asset-modal').classList.remove('hidden')"
              class="flex-1 inline-flex justify-center items-center px-4 py-3 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-emerald-500"
            >
              <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                />
              </svg>
              Add Asset
            </button>

            <button
              hx-post={~p"/assets/update_all_prices"}
              hx-target="#update-all-prices-success"
              hx-swap="innerHTML"
              hx-indicator="#update-all-prices-spinner"
              hx-on::before-request="document.getElementById('update-all-prices-icon').classList.add('hidden'); document.getElementById('update-all-prices-success').classList.add('hidden');"
              hx-on::after-request="if(event.detail.xhr.status >= 200 && event.detail.xhr.status < 300) { document.getElementById('update-all-prices-success').classList.remove('hidden'); document.getElementById('update-all-prices-icon').classList.remove('hidden'); setTimeout(() => { document.getElementById('update-all-prices-success').classList.add('hidden'); location.reload(); }, 2000); } else { document.getElementById('update-all-prices-icon').classList.remove('hidden'); }"
              class="flex-1 inline-flex justify-center items-center px-4 py-3 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <svg
                id="update-all-prices-icon"
                class="w-4 h-4 mr-1.5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
              <svg
                id="update-all-prices-spinner"
                class="htmx-indicator w-4 h-4 mr-1.5 animate-spin"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                >
                </circle>
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                >
                </path>
              </svg>
              Update Prices & Dividends
            </button>
          </div>

          <div
            id="update-all-prices-success"
            class="hidden mb-4 p-3 bg-green-100 border border-green-400 text-green-700 rounded"
          >
          </div>
          
    <!-- Filter Form -->
          <form method="get" action={~p"/assets"} class="mb-4">
            <div class="flex gap-2">
              <input
                type="text"
                name="filter"
                value={@filter}
                placeholder="Search by asset name or tag..."
                class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <button
                type="submit"
                class="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-emerald-500"
              >
                Filter
              </button>
              <%= if @filter != "" do %>
                <a
                  href={~p"/assets"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Clear
                </a>
              <% end %>
            </div>
          </form>
          
    <!-- Assets List -->
          <div id="assets-list" class="space-y-4">
            <%= for asset <- @assets do %>
              <.asset_item asset={asset} />
            <% end %>
          </div>
        </div>
        
    <!-- Asset Modal -->
        <div
          id="asset-modal"
          class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        >
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium text-gray-900">Add New Asset</h3>
                <button
                  onclick="document.getElementById('asset-modal').classList.add('hidden')"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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

              <div id="asset-form-errors"></div>

              <div class="relative">
                <!-- Loading overlay -->
                <div
                  id="asset-form-overlay"
                  class="htmx-indicator absolute inset-0 bg-gray-100 bg-opacity-75 flex items-center justify-center rounded-lg z-10"
                >
                  <div class="text-center">
                    <svg
                      class="h-8 w-8 animate-spin text-emerald-600 mx-auto mb-2"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      >
                      </circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      >
                      </path>
                    </svg>
                    <p class="text-sm text-gray-700">Saving asset...</p>
                  </div>
                </div>

                <form
                  action={~p"/assets"}
                  method="post"
                  id="asset-form"
                  hx-post={~p"/assets"}
                  hx-target="#assets-list"
                  hx-swap="afterbegin"
                  hx-indicator="#asset-form-overlay"
                  hx-on::response-error="document.getElementById('asset-form-errors').innerHTML = event.detail.xhr.responseText;"
                  hx-on::after-request="if(event.detail.successful) { document.getElementById('asset-form').reset(); document.getElementById('asset-modal').classList.add('hidden'); document.getElementById('asset-form-errors').innerHTML = ''; }"
                  class="space-y-4"
                >
                  <input type="hidden" name="_csrf_token" value={get_csrf_token()} />

                  <div>
                    <label for="asset_name" class="block text-sm font-medium text-gray-700">
                      Name
                    </label>
                    <input
                      type="text"
                      id="asset_name"
                      name="asset[name]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      placeholder="e.g. Apple Inc."
                    />
                  </div>

                  <div>
                    <label for="asset_price_url" class="block text-sm font-medium text-gray-700">
                      Price URL
                    </label>
                    <input
                      type="text"
                      id="asset_price_url"
                      name="asset[price_url]"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      placeholder="e.g. https://example.com/price"
                    />
                  </div>

                  <div>
                    <label for="asset_currency" class="block text-sm font-medium text-gray-700">
                      Currency
                    </label>
                    <select
                      id="asset_currency"
                      name="asset[currency]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    >
                      <%= for {label, value} <- Currency.currency_options_with_default() do %>
                        <option value={value}>{label}</option>
                      <% end %>
                    </select>
                  </div>

                  <div class="flex items-center">
                    <input type="hidden" name="asset[distributes_dividends]" value="false" />
                    <input
                      type="checkbox"
                      id="asset_distributes_dividends"
                      name="asset[distributes_dividends]"
                      value="true"
                      class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded"
                    />
                    <label for="asset_distributes_dividends" class="ml-2 block text-sm text-gray-700">
                      Distributes dividends
                    </label>
                  </div>

                  <div>
                    <label for="asset_dividend_url" class="block text-sm font-medium text-gray-700">
                      Dividend URL
                    </label>
                    <input
                      type="text"
                      id="asset_dividend_url"
                      name="asset[dividend_url]"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      placeholder="e.g. https://example.com/dividends"
                    />
                  </div>

                  <div>
                    <label
                      for="asset_dividend_withholding_tax"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Dividend Withholding Tax
                    </label>
                    <select
                      id="asset_dividend_withholding_tax"
                      name="asset[dividend_withholding_tax]"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    >
                      <option value="">Select rate</option>
                      <option value="0.0">0%</option>
                      <option value="0.05">5%</option>
                      <option value="0.1">10%</option>
                      <option value="0.15">15%</option>
                      <option value="0.2">20%</option>
                      <option value="0.25">25%</option>
                      <option value="0.3">30%</option>
                      <option value="0.35">35%</option>
                      <option value="0.4">40%</option>
                      <option value="0.45">45%</option>
                      <option value="0.5">50%</option>
                    </select>
                  </div>

                  <div class="flex gap-3 pt-4">
                    <button
                      type="submit"
                      class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2 relative"
                    >
                      <span class="htmx-indicator" id="asset-form-spinner">
                        <svg
                          class="absolute left-1/2 top-1/2 -ml-3 -mt-3 h-6 w-6 animate-spin text-white"
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                        >
                          <circle
                            class="opacity-25"
                            cx="12"
                            cy="12"
                            r="10"
                            stroke="currentColor"
                            stroke-width="4"
                          >
                          </circle>
                          <path
                            class="opacity-75"
                            fill="currentColor"
                            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                          >
                          </path>
                        </svg>
                      </span>
                      <span class="htmx-indicator:opacity-0">Add Asset</span>
                    </button>
                    <button
                      type="button"
                      onclick="document.getElementById('asset-modal').classList.add('hidden')"
                      class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>

        <.tab_bar current_tab="assets">
          <:tab navigate={~p"/dashboard"} name="dashboard" icon="hero-home">
            Dashboard
          </:tab>
          <:tab navigate={~p"/positions"} name="positions" icon="hero-chart-bar">
            Positions
          </:tab>
          <:tab navigate={~p"/assets"} name="assets" icon="hero-squares-2x2">
            Assets
          </:tab>
          <:tab navigate={~p"/portfolio_transactions"} name="transactions" icon="hero-document-text">
            Transactions
          </:tab>
          <:tab navigate={~p"/portfolios"} name="portfolios" icon="hero-folder">
            Portfolios
          </:tab>
        </.tab_bar>
      </div>
    </.tab_content>
    """
  end

  def asset_item(assigns) do
    ~H"""
    <div id={"asset-#{@asset.id}"} class="bg-white rounded-lg shadow p-4">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <div id={"asset-view-#{@asset.id}"}>
            <div class="mb-2">
              <h3 class="font-semibold text-gray-900">{@asset.name}</h3>
            </div>
            <%= if @asset.price do %>
              <p class="text-xl font-bold text-emerald-600">
                {@asset.currency} {Decimal.to_string(@asset.price)}
              </p>
            <% else %>
              <p class="text-gray-500 italic">Price not set</p>
            <% end %>
            <p class="text-sm text-gray-500 mt-2">
              Added {Calendar.strftime(@asset.inserted_at, "%B %d, %Y")}
            </p>
          </div>

          <div id={"asset-edit-#{@asset.id}"} class="hidden">
            <div id={"asset-edit-errors-#{@asset.id}"}></div>

            <div class="relative">
              <!-- Loading overlay -->
              <div
                id={"asset-edit-overlay-#{@asset.id}"}
                class="htmx-indicator absolute inset-0 bg-gray-100 bg-opacity-75 flex items-center justify-center rounded-lg z-10"
              >
                <div class="text-center">
                  <svg
                    class="h-8 w-8 animate-spin text-emerald-600 mx-auto mb-2"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                  <p class="text-sm text-gray-700">Saving asset...</p>
                </div>
              </div>

              <form
                id={"asset-edit-form-#{@asset.id}"}
                hx-put={~p"/assets/#{@asset.id}"}
                hx-target={"#asset-#{@asset.id}"}
                hx-swap="outerHTML"
                hx-indicator={"#asset-edit-overlay-#{@asset.id}"}
                hx-on::response-error={"document.getElementById('asset-edit-errors-#{@asset.id}').innerHTML = event.detail.xhr.responseText;"}
                hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
                class="space-y-3"
              >
                <div>
                  <label
                    for={"edit_name_#{@asset.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Name
                  </label>
                  <input
                    type="text"
                    id={"edit_name_#{@asset.id}"}
                    name="asset[name]"
                    value={@asset.name}
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label
                    for={"edit_price_url_#{@asset.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Price URL
                  </label>
                  <input
                    type="text"
                    id={"edit_price_url_#{@asset.id}"}
                    name="asset[price_url]"
                    value={@asset.price_url}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label
                    for={"edit_currency_#{@asset.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Currency
                  </label>
                  <select
                    id={"edit_currency_#{@asset.id}"}
                    name="asset[currency]"
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  >
                    <%= for {label, value} <- Currency.currency_options() do %>
                      <option value={value} selected={@asset.currency == value}>{label}</option>
                    <% end %>
                  </select>
                </div>

                <div class="flex items-center">
                  <input type="hidden" name="asset[distributes_dividends]" value="false" />
                  <input
                    type="checkbox"
                    id={"edit_distributes_dividends_#{@asset.id}"}
                    name="asset[distributes_dividends]"
                    value="true"
                    checked={@asset.distributes_dividends}
                    class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded"
                  />
                  <label
                    for={"edit_distributes_dividends_#{@asset.id}"}
                    class="ml-2 block text-sm text-gray-700"
                  >
                    Distributes dividends
                  </label>
                </div>

                <div>
                  <label
                    for={"edit_dividend_url_#{@asset.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Dividend URL
                  </label>
                  <input
                    type="text"
                    id={"edit_dividend_url_#{@asset.id}"}
                    name="asset[dividend_url]"
                    value={@asset.dividend_url}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label
                    for={"edit_dividend_withholding_tax_#{@asset.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Dividend Withholding Tax
                  </label>
                  <select
                    id={"edit_dividend_withholding_tax_#{@asset.id}"}
                    name="asset[dividend_withholding_tax]"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  >
                    <option value="">Select rate</option>
                    <option
                      value="0.0"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.0"))
                      }
                    >
                      0%
                    </option>
                    <option
                      value="0.05"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.05"))
                      }
                    >
                      5%
                    </option>
                    <option
                      value="0.1"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.1"))
                      }
                    >
                      10%
                    </option>
                    <option
                      value="0.15"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.15"))
                      }
                    >
                      15%
                    </option>
                    <option
                      value="0.2"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.2"))
                      }
                    >
                      20%
                    </option>
                    <option
                      value="0.25"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.25"))
                      }
                    >
                      25%
                    </option>
                    <option
                      value="0.3"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.3"))
                      }
                    >
                      30%
                    </option>
                    <option
                      value="0.35"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.35"))
                      }
                    >
                      35%
                    </option>
                    <option
                      value="0.4"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.4"))
                      }
                    >
                      40%
                    </option>
                    <option
                      value="0.45"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.45"))
                      }
                    >
                      45%
                    </option>
                    <option
                      value="0.5"
                      selected={
                        @asset.dividend_withholding_tax &&
                          Decimal.equal?(@asset.dividend_withholding_tax, Decimal.new("0.5"))
                      }
                    >
                      50%
                    </option>
                  </select>
                </div>

                <div class="flex gap-2">
                  <button
                    type="submit"
                    class="bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-1 px-3 rounded text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
                  >
                    Save
                  </button>
                  <button
                    type="button"
                    onclick={"document.getElementById('asset-view-#{@asset.id}').classList.remove('hidden'); document.getElementById('asset-edit-#{@asset.id}').classList.add('hidden');"}
                    class="bg-gray-600 hover:bg-gray-700 text-white font-medium py-1 px-3 rounded text-sm focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <div class="flex gap-2 ml-4">
          <%= if @asset.distributes_dividends do %>
            <button
              hx-get={~p"/assets/#{@asset.id}/dividends"}
              hx-target="body"
              hx-swap="beforeend"
              class="text-blue-600 hover:text-blue-800"
              title="View dividends"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
            </button>
          <% end %>
          <button
            onclick={"document.getElementById('asset-view-#{@asset.id}').classList.add('hidden'); document.getElementById('asset-edit-#{@asset.id}').classList.remove('hidden');"}
            class="text-emerald-600 hover:text-emerald-800"
            title="Edit asset"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
              >
              </path>
            </svg>
          </button>
          <button
            hx-delete={~p"/assets/#{@asset.id}"}
            hx-target={"#asset-#{@asset.id}"}
            hx-swap="outerHTML"
            hx-confirm="Are you sure you want to delete this asset?"
            hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
            class="text-red-600 hover:text-red-800"
            title="Delete asset"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              >
              </path>
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  def show(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="mb-6">
            <a href={~p"/assets"} class="text-emerald-600 hover:text-emerald-800 mb-4 inline-block">
              ← Back to Assets
            </a>
            <div class="bg-white rounded-lg shadow p-6">
              <div class="mb-4">
                <h1 class="text-2xl font-bold text-gray-900">{@asset.name}</h1>
              </div>
              <%= if @asset.price do %>
                <p class="text-3xl font-bold text-emerald-600 mb-4">
                  {@asset.currency} {Decimal.to_string(@asset.price)}
                </p>
              <% else %>
                <p class="text-gray-500 italic mb-4">Price not set</p>
              <% end %>
              <p class="text-sm text-gray-500">
                Added {Calendar.strftime(@asset.inserted_at, "%B %d, %Y at %I:%M %p")}
              </p>
              <div class="flex gap-3 mt-6">
                <a
                  href={~p"/assets/#{@asset}/edit"}
                  class="bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-2 px-4 rounded-lg"
                >
                  Edit Asset
                </a>
                <button
                  hx-delete={~p"/assets/#{@asset.id}"}
                  hx-confirm="Are you sure you want to delete this asset?"
                  hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
                  hx-on--after-request="window.location.href = '/assets'"
                  class="bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-lg"
                >
                  Delete Asset
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def new(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="mb-6">
            <a href={~p"/assets"} class="text-emerald-600 hover:text-emerald-800 mb-4 inline-block">
              ← Back to Assets
            </a>
            <h1 class="text-2xl font-bold text-gray-900">Add New Asset</h1>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <.form for={@changeset} action={~p"/assets"} class="space-y-4">
              <div>
                <.label for="asset_name">Name</.label>
                <.input type="text" field={@changeset[:name]} required placeholder="e.g. Apple Inc." />
              </div>

              <div>
                <.label for="asset_price_url">Price URL</.label>
                <.input
                  type="text"
                  field={@changeset[:price_url]}
                  placeholder="e.g. https://example.com/price"
                />
              </div>

              <div>
                <.label for="asset_currency">Currency</.label>
                <.input
                  type="select"
                  field={@changeset[:currency]}
                  required
                  options={Currency.currency_options_with_default()}
                />
              </div>

              <div>
                <.input
                  type="checkbox"
                  field={@changeset[:distributes_dividends]}
                  label="Distributes dividends"
                />
              </div>

              <div>
                <.label for="asset_dividend_url">Dividend URL</.label>
                <.input
                  type="text"
                  field={@changeset[:dividend_url]}
                  placeholder="e.g. https://example.com/dividends"
                />
              </div>

              <div>
                <.label for="asset_dividend_withholding_tax">Dividend Withholding Tax</.label>
                <.input
                  type="select"
                  field={@changeset[:dividend_withholding_tax]}
                  options={[
                    {"Select rate", ""},
                    {"0%", "0.0"},
                    {"5%", "0.05"},
                    {"10%", "0.1"},
                    {"15%", "0.15"},
                    {"20%", "0.2"},
                    {"25%", "0.25"},
                    {"30%", "0.3"},
                    {"35%", "0.35"},
                    {"40%", "0.4"},
                    {"45%", "0.45"},
                    {"50%", "0.5"}
                  ]}
                />
              </div>

              <div class="flex gap-3 pt-4">
                <.button type="submit" class="flex-1 bg-emerald-600 hover:bg-emerald-700">
                  Add Asset
                </.button>
                <a
                  href={~p"/assets"}
                  class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg text-center"
                >
                  Cancel
                </a>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def edit(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="mb-6">
            <a
              href={~p"/assets/#{@asset}"}
              class="text-emerald-600 hover:text-emerald-800 mb-4 inline-block"
            >
              ← Back to Asset
            </a>
            <h1 class="text-2xl font-bold text-gray-900">Edit Asset</h1>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <.form for={@changeset} action={~p"/assets/#{@asset}"} method="put" class="space-y-4">
              <div>
                <.label for="asset_name">Name</.label>
                <.input type="text" field={@changeset[:name]} required />
              </div>

              <div>
                <.label for="asset_price_url">Price URL</.label>
                <.input type="text" field={@changeset[:price_url]} />
              </div>

              <div>
                <.label for="asset_currency">Currency</.label>
                <.input
                  type="select"
                  field={@changeset[:currency]}
                  required
                  options={Currency.currency_options()}
                />
              </div>

              <div>
                <.input
                  type="checkbox"
                  field={@changeset[:distributes_dividends]}
                  label="Distributes dividends"
                />
              </div>

              <div>
                <.label for="asset_dividend_url">Dividend URL</.label>
                <.input
                  type="text"
                  field={@changeset[:dividend_url]}
                  placeholder="e.g. https://example.com/dividends"
                />
              </div>

              <div>
                <.label for="asset_dividend_withholding_tax">Dividend Withholding Tax</.label>
                <.input
                  type="select"
                  field={@changeset[:dividend_withholding_tax]}
                  options={[
                    {"Select rate", ""},
                    {"0%", "0.0"},
                    {"5%", "0.05"},
                    {"10%", "0.1"},
                    {"15%", "0.15"},
                    {"20%", "0.2"},
                    {"25%", "0.25"},
                    {"30%", "0.3"},
                    {"35%", "0.35"},
                    {"40%", "0.4"},
                    {"45%", "0.45"},
                    {"50%", "0.5"}
                  ]}
                />
              </div>

              <div class="flex gap-3 pt-4">
                <.button type="submit" class="flex-1 bg-emerald-600 hover:bg-emerald-700">
                  Update Asset
                </.button>
                <a
                  href={~p"/assets/#{@asset}"}
                  class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg text-center"
                >
                  Cancel
                </a>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def dividends_modal(assigns) do
    ~H"""
    <div
      id={"dividends-modal-#{@asset.id}"}
      class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
    >
      <div class="relative top-20 mx-auto p-5 border max-w-2xl shadow-lg rounded-md bg-white">
        <div class="mt-3">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-medium text-gray-900">
              Dividends for {@asset.name}
            </h3>
            <button
              onclick={"document.getElementById('dividends-modal-#{@asset.id}').remove()"}
              class="text-gray-400 hover:text-gray-600"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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

          <%= if Enum.empty?(@dividends) do %>
            <div class="text-center py-8 text-gray-500">
              <p>No dividends recorded for this asset.</p>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Ex-Date
                    </th>
                    <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Value
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Currency
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for dividend <- @dividends do %>
                    <tr>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                        {Calendar.strftime(dividend.date, "%B %d, %Y")}
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900 text-right font-medium">
                        {Decimal.to_string(dividend.value)}
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                        {dividend.currency}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>

          <div class="mt-4 text-sm text-gray-500 text-right">
            Total: {length(@dividends)} {if length(@dividends) == 1, do: "dividend", else: "dividends"}
          </div>
        </div>
      </div>
    </div>
    """
  end
end
