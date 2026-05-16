defmodule Boonorbust2.DividendSources.DateParser do
  @moduledoc false
  @spec parse_date(String.t()) :: {:ok, Date.t()} | {:error, String.t()}
  def parse_date(date_string) do
    cond do
      String.match?(date_string, ~r/^\d{1,2}\/\d{1,2}\/\d{4}$/) ->
        [day, month, year] = String.split(date_string, "/")
        parse_date_parts(day, month, year)

      String.match?(date_string, ~r/^\d{1,2}-\d{1,2}-\d{4}$/) ->
        [day, month, year] = String.split(date_string, "-")
        parse_date_parts(day, month, year)

      String.match?(date_string, ~r/^\d{4}-\d{1,2}-\d{1,2}$/) ->
        Date.from_iso8601(date_string)

      String.match?(date_string, ~r/^[A-Za-z]{3}\s+\d{1,2},\s+\d{4}$/) ->
        parse_month_day_year(date_string, true)

      String.match?(date_string, ~r/^[A-Za-z]{3}\s+\d{1,2}\s+\d{4}$/) ->
        parse_month_day_year(date_string, false)

      true ->
        {:error, "Invalid date format"}
    end
  end

  @spec parse_date_parts(String.t(), String.t(), String.t()) ::
          {:ok, Date.t()} | {:error, String.t()}
  def parse_date_parts(day, month, year) do
    with {day_int, _} <- Integer.parse(day),
         {month_int, _} <- Integer.parse(month),
         {year_int, _} <- Integer.parse(year),
         {:ok, date} <- Date.new(year_int, month_int, day_int) do
      {:ok, date}
    else
      _ -> {:error, "Invalid date"}
    end
  end

  @month_map %{
    "Jan" => 1,
    "Feb" => 2,
    "Mar" => 3,
    "Apr" => 4,
    "May" => 5,
    "Jun" => 6,
    "Jul" => 7,
    "Aug" => 8,
    "Sep" => 9,
    "Oct" => 10,
    "Nov" => 11,
    "Dec" => 12
  }

  @spec parse_month_day_year(String.t(), boolean()) :: {:ok, Date.t()} | {:error, String.t()}
  def parse_month_day_year(date_string, has_comma) do
    regex =
      if has_comma,
        do: ~r/^([A-Za-z]{3})\s+(\d{1,2}),\s+(\d{4})$/,
        else: ~r/^([A-Za-z]{3})\s+(\d{1,2})\s+(\d{4})$/

    case Regex.run(regex, date_string) do
      [_, month_str, day, year] ->
        case Map.get(@month_map, month_str) do
          nil -> {:error, "Invalid month name"}
          month_int -> parse_date_parts(day, Integer.to_string(month_int), year)
        end

      _ ->
        {:error, "Invalid date format"}
    end
  end
end
