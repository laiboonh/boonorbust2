defmodule Boonorbust2.PriceSources.FtMarkets do
  @moduledoc false
  @spec fetch(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def fetch(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url, []) do
      {:ok, %{status: 200, body: body}} -> parse_response(body)
      {:ok, %{status: status}} -> {:error, "HTTP request failed with status #{status}"}
      {:error, error} -> {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec parse_response(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def parse_response(body) do
    {:ok, document} = Floki.parse_document(body)

    result =
      Floki.find(
        document,
        "body > div.o-grid-container.mod-container > div:nth-child(2) > section:nth-child(1) > div > div > div.mod-tearsheet-overview__overview.clearfix > div.mod-tearsheet-overview__quote > ul > li:nth-child(1) > span.mod-ui-data-list__value"
      )
      |> Floki.text()
      |> String.split("\n")
      |> hd()

    {:ok, result}
  end
end
