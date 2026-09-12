defmodule Boonorbust2.IrrTest do
  use ExUnit.Case, async: true

  alias Boonorbust2.Irr

  describe "xirr/2" do
    test "returns the known rate for a simple invest-then-return-more cash flow" do
      start_date = ~D[2024-01-01]
      end_date = Date.add(start_date, 365)

      cash_flows = [
        {start_date, Decimal.new("-1000")},
        {end_date, Decimal.new("1200")}
      ]

      assert {:ok, rate} = Irr.xirr(cash_flows)
      assert_in_delta rate, 0.20, 0.0001
    end

    test "returns an error when all cash flows are the same sign" do
      cash_flows = [
        {~D[2024-01-01], Decimal.new("-1000")},
        {~D[2024-06-01], Decimal.new("-500")}
      ]

      assert Irr.xirr(cash_flows) == {:error, :no_sign_change}
    end

    test "returns an error for an empty list of cash flows" do
      assert Irr.xirr([]) == {:error, :no_sign_change}
    end

    test "returns an error when all cash flows fall on the same date" do
      same_date = ~D[2024-01-01]

      cash_flows = [
        {same_date, Decimal.new("-1000")},
        {same_date, Decimal.new("1000")}
      ]

      assert Irr.xirr(cash_flows) == {:error, :no_time_variance}
    end

    test "returns a negative rate for a net loss scenario" do
      start_date = ~D[2024-01-01]
      end_date = Date.add(start_date, 365)

      cash_flows = [
        {start_date, Decimal.new("-1000")},
        {end_date, Decimal.new("800")}
      ]

      assert {:ok, rate} = Irr.xirr(cash_flows)
      assert rate < 0
      assert_in_delta rate, -0.20, 0.0001
    end

    test "returns an explicit error instead of looping indefinitely when the iteration cap is hit" do
      start_date = ~D[2024-01-01]
      end_date = Date.add(start_date, 365)

      cash_flows = [
        {start_date, Decimal.new("-1000")},
        {end_date, Decimal.new("1200")}
      ]

      assert Irr.xirr(cash_flows, max_iterations: 0) == {:error, :max_iterations_exceeded}
    end
  end
end
