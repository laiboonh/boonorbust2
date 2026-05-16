defmodule Boonorbust2.DividendSources do
  @moduledoc false
  alias Boonorbust2.DividendSources.{Digrin, Divvydiary, Eodhd}
  alias Boonorbust2.PriceSources.{DividendsSg, Etnet}

  @spec fetch_dividends(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch_dividends("https://eodhd.com/" <> _ = url), do: Eodhd.fetch(url)

  def fetch_dividends("https://www.dividends.sg/" <> _ = url),
    do: DividendsSg.fetch_dividends(url)

  def fetch_dividends("https://www.etnet.com.hk/" <> _ = url), do: Etnet.fetch_dividends(url)
  def fetch_dividends("https://www.digrin.com/" <> _ = url), do: Digrin.fetch(url)
  def fetch_dividends("https://divvydiary.com/" <> _ = url), do: Divvydiary.fetch(url)
  def fetch_dividends(url), do: {:error, "Unexpected dividend url #{url}"}
end
