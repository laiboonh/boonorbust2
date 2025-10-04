defmodule Boonorbust2.HTTPClient.ReqAdapter do
  @moduledoc """
  Req implementation of HTTPClient behavior.
  """

  @behaviour Boonorbust2.HTTPClient

  @impl true
  def get(url, opts \\ []) do
    IO.puts("-----------------------------REQ-------------------------------")

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
