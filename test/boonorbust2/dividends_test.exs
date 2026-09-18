defmodule Boonorbust2.DividendsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Dividends
  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

  describe "fetch_dividends/1 for divvydiary.com" do
    # The real page embeds JSON with all quotes escaped as \" inside a JS string.
    @divvydiary_html ~S(<html><body><script>{"state":"\"dividends\":[{\"id\":1,\"exDate\":\"2025-03-13\",\"payDate\":\"2025-04-07\",\"amount\":0.1413,\"currency\":\"USD\",\"forecast\":false},{\"id\":2,\"exDate\":\"2025-02-13\",\"payDate\":\"2025-03-07\",\"amount\":0.1250,\"currency\":\"USD\",\"forecast\":true}]"}</script></body></html>)

    test "parses dividend entries and excludes forecasts" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts -> {:ok, %{status: 200, body: @divvydiary_html}} end)

      asset = %Asset{dividend_url: "https://divvydiary.com/en/some-etf-ISIN123"}

      {:ok, dividends} = Dividends.fetch_dividends(asset)

      assert length(dividends) == 1
      [div] = dividends
      assert div.ex_date == ~D[2025-03-13]
      assert div.pay_date == ~D[2025-04-07]
      assert Decimal.eq?(div.value, Decimal.new("0.1413"))
      assert div.currency == "USD"
    end

    test "returns error when no dividend data found" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: "<html><body>no data here</body></html>"}}
      end)

      asset = %Asset{dividend_url: "https://divvydiary.com/en/some-etf-ISIN123"}

      assert {:error, _reason} = Dividends.fetch_dividends(asset)
    end

    test "returns error on non-200 response" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts -> {:ok, %{status: 403}} end)

      asset = %Asset{dividend_url: "https://divvydiary.com/en/some-etf-ISIN123"}

      assert {:error, "HTTP request failed with status 403"} = Dividends.fetch_dividends(asset)
    end
  end

  describe "parse_dividends_sg_document/1" do
    test "parses dividend amounts in scientific notation correctly" do
      html = """
      <html>
      <table class="table-striped">
      <tbody>
      <tr>
        <td>2024</td>
        <td>5%</td>
        <td>SGD 0.05</td>
        <td>SGD2.0E-5</td>
        <td>2024-01-15</td>
        <td>2024-02-01</td>
        <td>Rate: SGD2.0E-5</td>
      </tr>
      </tbody>
      </table>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      {:ok, [dividend]} = Dividends.parse_dividends_sg_document(document)

      assert Decimal.eq?(dividend.value, Decimal.new("0.000020"))
      assert dividend.currency == "SGD"
    end

    test "parses standard decimal dividend amounts" do
      html = """
      <html>
      <table class="table-striped">
      <tbody>
      <tr>
        <td>2024</td>
        <td>5%</td>
        <td>SGD 0.05</td>
        <td>SGD0.0185</td>
        <td>2024-01-15</td>
        <td>2024-02-01</td>
        <td>Rate: SGD0.0185</td>
      </tr>
      </tbody>
      </table>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      {:ok, [dividend]} = Dividends.parse_dividends_sg_document(document)

      assert Decimal.eq?(dividend.value, Decimal.new("0.0185"))
      assert dividend.currency == "SGD"
    end

    test "parses amounts with a space between currency and amount (current dividends.sg format)" do
      html = """
      <html>
      <table class="table-striped">
      <tbody>
      <tr>
        <td class="text-nowrap">SGD 0.81</td>
        <td class='dividend-history-table__date'>2026-08-14</td>
        <td class='dividend-history-table__date'>2026-08-25</td>
        <td class="dividend-history-table__particulars">Rate: SGD 0.81 Per Security</td>
      </tr>
      </tbody>
      </table>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      {:ok, [dividend]} = Dividends.parse_dividends_sg_document(document)

      assert Decimal.eq?(dividend.value, Decimal.new("0.81"))
      assert dividend.currency == "SGD"
    end
  end
end
