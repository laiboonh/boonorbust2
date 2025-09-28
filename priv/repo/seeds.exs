# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Boonorbust2.Repo.insert!(%Boonorbust2.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Boonorbust2.Repo
alias Boonorbust2.Messages.Message
alias Boonorbust2.Assets.Asset

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

# Insert some sample assets
sample_assets = [
  %Asset{name: "Apple Inc.", code: "AAPL", price: Decimal.new("175.43"), currency: "USD"},
  %Asset{
    name: "Microsoft Corporation",
    code: "MSFT",
    price: Decimal.new("378.85"),
    currency: "USD"
  },
  %Asset{name: "Tesla, Inc.", code: "TSLA", price: Decimal.new("248.42"), currency: "USD"},
  %Asset{name: "NVIDIA Corporation", code: "NVDA", price: Decimal.new("875.28"), currency: "USD"},
  %Asset{name: "Bitcoin", code: "BTC", price: Decimal.new("67432.50"), currency: "USD"}
]

Enum.each(sample_assets, &Repo.insert!/1)
