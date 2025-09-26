defmodule Boonorbust2Web.MessageHTML do
  use Boonorbust2Web, :html

  def index(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-6">
      <div class="max-w-2xl mx-auto px-4">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Hello World Messages</h1>
          <button
            onclick="document.getElementById('message-modal').classList.remove('hidden')"
            class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 flex items-center gap-2"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4">
              </path>
            </svg>
            Add Message
          </button>
        </div>
        
    <!-- Messages List -->
        <div id="messages-list" class="space-y-4">
          <%= for message <- @messages do %>
            <.message_item message={message} />
          <% end %>
        </div>
        
    <!-- Message Modal -->
        <div
          id="message-modal"
          class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        >
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium text-gray-900">Add New Message</h3>
                <button
                  onclick="document.getElementById('message-modal').classList.add('hidden')"
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
                action={~p"/messages"}
                method="post"
                id="message-form"
                hx-post={~p"/messages"}
                hx-target="#messages-list"
                hx-swap="afterbegin"
                hx-on--after-request="document.getElementById('message-form').reset(); document.getElementById('message-modal').classList.add('hidden');"
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

                <div class="flex gap-3 pt-4">
                  <button
                    type="submit"
                    class="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                  >
                    Send Message
                  </button>
                  <button
                    type="button"
                    onclick="document.getElementById('message-modal').classList.add('hidden')"
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
    </div>
    """
  end

  def message_item(assigns) do
    ~H"""
    <div id={"message-#{@message.id}"} class="bg-white rounded-lg shadow p-4">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <div id={"message-view-#{@message.id}"}>
            <h3 class="font-semibold text-gray-900">{@message.author}</h3>
            <p class="text-gray-700 mt-1">{@message.content}</p>
            <p class="text-sm text-gray-500 mt-2">
              {Calendar.strftime(@message.inserted_at, "%B %d, %Y at %I:%M %p")}
            </p>
          </div>
          <div id={"message-edit-#{@message.id}"} class="hidden">
            <form
              hx-put={~p"/messages/#{@message.id}"}
              hx-target={"#message-#{@message.id}"}
              hx-swap="outerHTML"
              hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
              class="space-y-3"
            >
              <div>
                <label
                  for={"edit_author_#{@message.id}"}
                  class="block text-sm font-medium text-gray-700"
                >
                  Author
                </label>
                <input
                  type="text"
                  id={"edit_author_#{@message.id}"}
                  name="message[author]"
                  value={@message.author}
                  required
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              </div>
              <div>
                <label
                  for={"edit_content_#{@message.id}"}
                  class="block text-sm font-medium text-gray-700"
                >
                  Message
                </label>
                <textarea
                  id={"edit_content_#{@message.id}"}
                  name="message[content]"
                  required
                  rows="3"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                >{@message.content}</textarea>
              </div>
              <div class="flex gap-2">
                <button
                  type="submit"
                  class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-1 px-3 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                >
                  Save
                </button>
                <button
                  type="button"
                  onclick={"document.getElementById('message-view-#{@message.id}').classList.remove('hidden'); document.getElementById('message-edit-#{@message.id}').classList.add('hidden');"}
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
            onclick={"document.getElementById('message-view-#{@message.id}').classList.add('hidden'); document.getElementById('message-edit-#{@message.id}').classList.remove('hidden');"}
            class="text-blue-600 hover:text-blue-800"
            title="Edit message"
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
            hx-delete={~p"/messages/#{@message.id}"}
            hx-target={"#message-#{@message.id}"}
            hx-swap="outerHTML"
            hx-confirm="Are you sure you want to delete this message?"
            hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
            class="text-red-600 hover:text-red-800"
            title="Delete message"
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
end
