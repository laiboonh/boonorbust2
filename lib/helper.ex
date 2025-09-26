defmodule Helper do
  @moduledoc """
  Helper module for utility functions.
  """
  use Retry

  @type rescue_only :: [atom()]

  @spec do_retry(module(), atom(), [any()], rescue_only()) :: any()
  def do_retry(module, function, argument, rescue_only) do
    retry with: exponential_backoff() |> randomize |> expiry(10_000),
          rescue_only: rescue_only do
      apply(module, function, argument)
    after
      result -> result
    else
      error -> error
    end
  end
end
