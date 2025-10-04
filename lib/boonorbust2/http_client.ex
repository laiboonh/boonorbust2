defmodule Boonorbust2.HTTPClient do
  @moduledoc """
  Behavior for HTTP client operations.
  """

  @type response :: {:ok, map()} | {:error, term()}

  @callback get(url :: String.t(), opts :: keyword()) :: response()
end
