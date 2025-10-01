defmodule Boonorbust2.Cldr do
  @moduledoc """
  CLDR backend for ex_money localization and currency formatting.
  """

  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Number, Money]
end
