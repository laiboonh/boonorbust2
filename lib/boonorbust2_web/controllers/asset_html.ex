defmodule Boonorbust2Web.AssetHTML do
  use Boonorbust2Web, :html

  alias Boonorbust2.Currency

  def index(assigns) do
    ~H"""
    <.tab_content class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="text-center mb-6">
            <h1 class="text-2xl font-bold text-gray-900 mb-2">BoonOrBust</h1>
            <h2 class="text-xl text-gray-700 mb-4">Assets</h2>
          </div>

          <button
            onclick="document.getElementById('asset-modal').classList.remove('hidden')"
            class="w-full inline-flex justify-center items-center px-6 py-4 bg-emerald-600 text-white text-lg font-medium rounded-xl hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-emerald-500 mb-6"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 6v6m0 0v6m0-6h6m-6 0H6"
              />
            </svg>
            Add Asset
          </button>
          
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

              <form
                action={~p"/assets"}
                method="post"
                id="asset-form"
                hx-post={~p"/assets"}
                hx-target="#assets-list"
                hx-swap="afterbegin"
                hx-on--after-request="document.getElementById('asset-form').reset(); document.getElementById('asset-modal').classList.add('hidden');"
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
                  <label for="asset_code" class="block text-sm font-medium text-gray-700">
                    Code
                  </label>
                  <input
                    type="text"
                    id="asset_code"
                    name="asset[code]"
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    placeholder="e.g. AAPL"
                  />
                </div>

                <div>
                  <label for="asset_price" class="block text-sm font-medium text-gray-700">
                    Price
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    id="asset_price"
                    name="asset[price]"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    placeholder="e.g. 150.00"
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

                <div class="flex gap-3 pt-4">
                  <button
                    type="submit"
                    class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
                  >
                    Add Asset
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

        <.tab_bar current_tab="assets">
          <:tab navigate={~p"/messages"} name="messages" icon="hero-chat-bubble-left">
            Messages
          </:tab>
          <:tab navigate={~p"/assets"} name="assets" icon="hero-chart-bar">
            Assets
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
            <div class="flex justify-between items-start mb-2">
              <h3 class="font-semibold text-gray-900">{@asset.name}</h3>
              <span class="bg-emerald-100 text-emerald-800 text-xs font-medium px-2.5 py-0.5 rounded">
                {@asset.code}
              </span>
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
            <form
              hx-put={~p"/assets/#{@asset.id}"}
              hx-target={"#asset-#{@asset.id}"}
              hx-swap="outerHTML"
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
                  for={"edit_code_#{@asset.id}"}
                  class="block text-sm font-medium text-gray-700"
                >
                  Code
                </label>
                <input
                  type="text"
                  id={"edit_code_#{@asset.id}"}
                  name="asset[code]"
                  value={@asset.code}
                  required
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                />
              </div>

              <div>
                <label
                  for={"edit_price_#{@asset.id}"}
                  class="block text-sm font-medium text-gray-700"
                >
                  Price
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  id={"edit_price_#{@asset.id}"}
                  name="asset[price]"
                  value={if @asset.price, do: Decimal.to_string(@asset.price), else: ""}
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

        <div class="flex gap-2 ml-4">
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
              <div class="flex justify-between items-start mb-4">
                <h1 class="text-2xl font-bold text-gray-900">{@asset.name}</h1>
                <span class="bg-emerald-100 text-emerald-800 text-sm font-medium px-3 py-1 rounded">
                  {@asset.code}
                </span>
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
                <.label for="asset_code">Code</.label>
                <.input type="text" field={@changeset[:code]} required placeholder="e.g. AAPL" />
              </div>

              <div>
                <.label for="asset_price">Price</.label>
                <.input
                  type="number"
                  step="0.01"
                  min="0"
                  field={@changeset[:price]}
                  placeholder="e.g. 150.00"
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
                <.label for="asset_code">Code</.label>
                <.input type="text" field={@changeset[:code]} required />
              </div>

              <div>
                <.label for="asset_price">Price</.label>
                <.input type="number" step="0.01" min="0" field={@changeset[:price]} />
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
end
