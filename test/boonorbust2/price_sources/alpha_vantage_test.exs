defmodule Boonorbust2.PriceSources.AlphaVantageTest do
  use ExUnit.Case, async: true

  alias Boonorbust2.PriceSources.AlphaVantage

  describe "parse_response/1" do
    test "parses the latest close price from the time series" do
      body = %{
        "Time Series (Daily)" => %{
          "2024-01-02" => %{"4. close" => "101.50"},
          "2024-01-01" => %{"4. close" => "100.00"}
        }
      }

      assert AlphaVantage.parse_response(body) == {:ok, "101.50"}
    end

    test "returns an error when the time series is empty" do
      body = %{"Time Series (Daily)" => %{}}

      assert AlphaVantage.parse_response(body) == {:error, "No data available"}
    end

    test "returns an error for an API error message" do
      body = %{"Error Message" => "Invalid API call"}

      assert AlphaVantage.parse_response(body) == {:error, "API error: Invalid API call"}
    end

    test "returns a rate limit error for the legacy Note key" do
      body = %{"Note" => "Thank you for using Alpha Vantage! Our standard API rate limit is..."}

      assert AlphaVantage.parse_response(body) ==
               {:error,
                "API limit reached: Thank you for using Alpha Vantage! Our standard API rate limit is..."}
    end

    test "returns a rate limit error for the current Information key" do
      body = %{
        "Information" =>
          "Thank you for using Alpha Vantage! Our standard API rate limit is 25 requests per day."
      }

      assert AlphaVantage.parse_response(body) ==
               {:error,
                "API limit reached: Thank you for using Alpha Vantage! Our standard API rate limit is 25 requests per day."}
    end

    test "returns an error for an unrecognized response shape" do
      body = %{"unexpected" => "shape"}

      assert AlphaVantage.parse_response(body) == {:error, "Invalid response format"}
    end
  end
end
