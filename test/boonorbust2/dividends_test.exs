defmodule Boonorbust2.DividendsTest do
  use ExUnit.Case, async: true

  alias Boonorbust2.Dividends

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
  end
end
