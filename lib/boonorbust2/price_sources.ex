defmodule Boonorbust2.PriceSources do
  @moduledoc false
  alias Boonorbust2.PriceSources.{
    AlphaVantage,
    DividendsSg,
    Dollardex,
    Etnet,
    ExchangeRateApi,
    FtMarkets,
    Marketstack
  }

  @spec fetch_price(String.t()) :: {:ok, any()} | {:error, String.t()}
  def fetch_price("https://api.marketstack.com" <> _ = url), do: Marketstack.fetch(url)
  def fetch_price("https://www.dollardex.com/" <> _ = url), do: Dollardex.fetch(url)
  def fetch_price("https://markets.ft.com/" <> _ = url), do: FtMarkets.fetch(url)
  def fetch_price("https://www.alphavantage.co/" <> _ = url), do: AlphaVantage.fetch(url)
  def fetch_price("https://v6.exchangerate-api.com/" <> _ = url), do: ExchangeRateApi.fetch(url)
  def fetch_price("https://www.etnet.com.hk/" <> _ = url), do: Etnet.fetch_price(url)
  def fetch_price("https://www.dividends.sg/" <> _ = url), do: DividendsSg.fetch_price(url)
  def fetch_price(url), do: {:error, "Unexpected price url #{url}"}

  @spec fetch_combined(String.t()) ::
          {:ok, {any(), [map()]}} | {:error, String.t()} | {:error, :unsupported}
  def fetch_combined("https://www.dividends.sg/" <> _ = url), do: DividendsSg.fetch_combined(url)
  def fetch_combined("https://www.etnet.com.hk/" <> _ = url), do: Etnet.fetch_combined(url)
  def fetch_combined(_url), do: {:error, :unsupported}
end
