# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     HelloWorld.Repo.insert!(%HelloWorld.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias HelloWorld.{Repo, Message}

# Insert some sample messages
sample_messages = [
  %Message{author: "Alice", content: "Hello, world! This is my first message."},
  %Message{author: "Bob", content: "Phoenix with HTMX is awesome!"},
  %Message{
    author: "Charlie",
    content: "I love how interactive this feels without any JavaScript frameworks."
  }
]

Enum.each(sample_messages, &Repo.insert!/1)
