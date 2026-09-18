defmodule Boonorbust2.PriceSources.DividendsSgTest do
  use ExUnit.Case, async: true

  alias Boonorbust2.PriceSources.DividendsSg

  describe "parse_price/1" do
    test "parses price from the current dividend-company-price markup" do
      html = """
      <html>
      <div class="dividend-company-quote">
        <strong class="dividend-company-price">6.02</strong>
        <span class="dividend-company-currency">SGD</span>
      </div>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)

      assert DividendsSg.parse_price(document) == {:ok, "6.02"}
    end

    test "returns error when price markup is absent" do
      html = "<html><body>no price here</body></html>"
      {:ok, document} = Floki.parse_document(html)

      assert DividendsSg.parse_price(document) == {:error, :price_not_found}
    end
  end
end
