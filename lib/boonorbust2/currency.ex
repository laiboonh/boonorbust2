defmodule Boonorbust2.Currency do
  @moduledoc """
  Utilities for handling currencies in the application.
  """

  @supported_currencies ["USD", "EUR", "GBP", "SGD", "JPY"]

  @doc """
  Returns a list of supported currency codes.
  """
  @spec supported_currencies() :: [String.t()]
  def supported_currencies, do: @supported_currencies

  @doc """
  Returns a list of currency options formatted for HTML select dropdowns.
  Each option is a tuple of {display_name, value}.
  """
  @spec currency_options() :: [{String.t(), String.t()}]
  def currency_options do
    Enum.map(supported_currencies(), fn currency -> {currency, currency} end)
  end

  @doc """
  Returns currency options with a default "Select currency" option at the beginning.
  """
  @spec currency_options_with_default() :: [{String.t(), String.t()}]
  def currency_options_with_default do
    [{"Select currency", ""} | currency_options()]
  end

  @doc """
  Validates if a given currency code is supported.
  """
  @spec valid_currency?(String.t()) :: boolean()
  def valid_currency?(currency) when is_binary(currency) do
    currency in @supported_currencies
  end

  def valid_currency?(_), do: false
end
