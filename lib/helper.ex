defmodule Helper do
  @moduledoc """
  Helper module for utility functions.
  """
  use Retry

  @type rescue_only :: [atom()]

  @spec do_retry(function(), rescue_only()) :: any()
  def do_retry(func, rescue_only) do
    retry with: exponential_backoff() |> randomize |> expiry(15_000),
          rescue_only: rescue_only do
      func.()
    after
      result -> result
    else
      error -> error
    end
  end
end
