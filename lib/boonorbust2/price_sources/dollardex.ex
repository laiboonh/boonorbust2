defmodule Boonorbust2.PriceSources.Dollardex do
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
      Floki.find(document, "#grid1 > div > div.price.clear")
      |> Floki.text()
      |> String.split("\n")
      |> hd()

    {:ok, result}
  end
end
