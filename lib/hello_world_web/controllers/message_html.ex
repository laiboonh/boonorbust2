defmodule HelloWorldWeb.MessageHTML do
  use HelloWorldWeb, :html

  def index(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-6">
      <div class="max-w-2xl mx-auto px-4">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Hello World Messages</h1>

    <!-- Message Form -->
        <div class="bg-white rounded-lg shadow p-6 mb-6">
          <form
            action={~p"/messages"}
            method="post"
            id="message-form"
            hx-post={~p"/messages"}
            hx-target="#messages-list"
            hx-swap="afterbegin"
            hx-on--after-request="document.getElementById('message-form').reset()"
            class="space-y-4"
          >
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />

            <div>
              <label for="message_author" class="block text-sm font-medium text-gray-700">
                Author
              </label>
              <input
                type="text"
                id="message_author"
                name="message[author]"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="message_content" class="block text-sm font-medium text-gray-700">
                Message
              </label>
              <textarea
                id="message_content"
                name="message[content]"
                required
                rows="3"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              ></textarea>
            </div>

            <button
              type="submit"
              class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            >
              Send Message
            </button>
          </form>
        </div>

    <!-- Messages List -->
        <div id="messages-list" class="space-y-4">
          <%= for message <- @messages do %>
            <.message_item message={message} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def message_item(assigns) do
    ~H"""
    <div id={"message-#{@message.id}"} class="bg-white rounded-lg shadow p-4">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <h3 class="font-semibold text-gray-900">{@message.author}</h3>
          <p class="text-gray-700 mt-1">{@message.content}</p>
          <p class="text-sm text-gray-500 mt-2">
            {Calendar.strftime(@message.inserted_at, "%B %d, %Y at %I:%M %p")}
          </p>
        </div>
        <button
          hx-delete={~p"/messages/#{@message.id}"}
          hx-target={"#message-#{@message.id}"}
          hx-swap="outerHTML"
          hx-confirm="Are you sure you want to delete this message?"
          hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
          class="text-red-600 hover:text-red-800 ml-4"
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
    """
  end
end
