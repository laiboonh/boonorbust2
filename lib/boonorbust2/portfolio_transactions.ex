defmodule Boonorbust2.PortfolioTransactions do
  @moduledoc """
  Context module for managing portfolio transactions.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Assets
  alias Boonorbust2.PortfolioTransactions.PortfolioTransaction
  alias Boonorbust2.Repo

  @spec list_portfolio_transactions() :: [PortfolioTransaction.t()]
  def list_portfolio_transactions do
    Helper.do_retry(
      fn ->
        Repo.all(
          from pt in PortfolioTransaction,
            order_by: [desc: pt.transaction_date],
            preload: [:asset]
        )
      end,
      [DBConnection.ConnectionError]
    )
  end

  @spec get_portfolio_transaction!(integer()) :: PortfolioTransaction.t()
  def get_portfolio_transaction!(id),
    do: Repo.get!(PortfolioTransaction, id) |> Repo.preload(:asset)

  @spec get_portfolio_transaction(integer()) :: PortfolioTransaction.t() | nil
  def get_portfolio_transaction(id),
    do: Repo.get(PortfolioTransaction, id) |> Repo.preload(:asset)

  @spec create_portfolio_transaction(map()) ::
          {:ok, PortfolioTransaction.t()} | {:error, Ecto.Changeset.t()}
  def create_portfolio_transaction(attrs \\ %{}) do
    %PortfolioTransaction{}
    |> PortfolioTransaction.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_portfolio_transaction(PortfolioTransaction.t(), map()) ::
          {:ok, PortfolioTransaction.t()} | {:error, Ecto.Changeset.t()}
  def update_portfolio_transaction(%PortfolioTransaction{} = portfolio_transaction, attrs) do
    portfolio_transaction
    |> PortfolioTransaction.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_portfolio_transaction(PortfolioTransaction.t()) ::
          {:ok, PortfolioTransaction.t()} | {:error, Ecto.Changeset.t()}
  def delete_portfolio_transaction(%PortfolioTransaction{} = portfolio_transaction) do
    Repo.delete(portfolio_transaction)
  end

  @spec change_portfolio_transaction(PortfolioTransaction.t(), map()) :: Ecto.Changeset.t()
  def change_portfolio_transaction(%PortfolioTransaction{} = portfolio_transaction, attrs \\ %{}) do
    PortfolioTransaction.changeset(portfolio_transaction, attrs)
  end

  @doc """
  Imports portfolio transactions from a CSV file.

  Expected CSV format:
  Stock,Action,Shares,Price,Commission,Amount,Date,Reason

  The function will:
  - Parse each row
  - Look up or create assets by name
  - Create portfolio transactions
  - Return a summary of the import
  """
  @spec import_from_csv(String.t()) :: {:ok, map()} | {:error, String.t()}
  def import_from_csv(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        process_csv_content(content)

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end

  @spec process_csv_content(String.t()) ::
          {:ok,
           %{
             total: non_neg_integer(),
             success: non_neg_integer(),
             errors: non_neg_integer(),
             error_details: [String.t()]
           }}
  defp process_csv_content(content) do
    lines = String.split(content, "\n", trim: true)

    case lines do
      [_header | data_lines] ->
        results = Enum.map(data_lines, &process_csv_row/1)

        successes = Enum.filter(results, fn {status, _} -> status == :ok end)
        errors = Enum.filter(results, fn {status, _} -> status == :error end)

        {:ok,
         %{
           total: length(data_lines),
           success: length(successes),
           errors: length(errors),
           error_details: Enum.map(errors, fn {:error, msg} -> msg end)
         }}

      [] ->
        {:ok, %{total: 0, success: 0, errors: 0, error_details: []}}
    end
  end

  @spec process_csv_row(String.t()) :: {:ok, PortfolioTransaction.t()} | {:error, String.t()}
  defp process_csv_row(line) do
    with {:ok, data} <- parse_csv_line(line),
         {:ok, asset} <- find_or_create_asset(data.stock),
         {:ok, transaction} <- create_transaction_from_data(data, asset) do
      {:ok, transaction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec create_transaction_from_data(map(), Assets.Asset.t()) ::
          {:ok, PortfolioTransaction.t()} | {:error, String.t()}
  defp create_transaction_from_data(data, asset) do
    transaction_attrs = %{
      asset_id: asset.id,
      action: String.downcase(data.action),
      shares: data.shares,
      price: data.price,
      commission: data.commission,
      amount: data.amount,
      transaction_date: data.date
    }

    case create_portfolio_transaction(transaction_attrs) do
      {:ok, transaction} ->
        {:ok, transaction}

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        {:error, "Failed to create transaction: #{inspect(errors)}"}
    end
  end

  @spec parse_csv_line(String.t()) :: {:ok, map()} | {:error, String.t()}
  defp parse_csv_line(line) do
    with {:ok, fields} <- safe_parse_csv_fields(line),
         {:ok, parsed_data} <- parse_csv_data(fields) do
      {:ok, parsed_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec safe_parse_csv_fields(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  defp safe_parse_csv_fields(line) do
    {:ok, parse_csv_fields(line)}
  rescue
    e -> {:error, "Parse error: #{Exception.message(e)}"}
  end

  @spec parse_csv_data([String.t()]) :: {:ok, map()} | {:error, String.t()}
  defp parse_csv_data(fields) do
    case fields do
      [stock, action, shares, price, commission, amount, date | _] ->
        with {:ok, shares_decimal} <- parse_decimal(shares),
             {:ok, price_decimal} <- parse_decimal(price),
             {:ok, commission_decimal} <- parse_decimal(commission),
             {:ok, amount_decimal} <- parse_decimal(amount),
             {:ok, parsed_date} <- parse_date(date) do
          {:ok,
           %{
             stock: String.trim(stock),
             action: String.trim(action),
             shares: shares_decimal,
             price: price_decimal,
             commission: commission_decimal,
             amount: amount_decimal,
             date: parsed_date
           }}
        else
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, "Invalid number of fields"}
    end
  end

  @spec parse_csv_fields(String.t()) :: [String.t()]
  defp parse_csv_fields(line) do
    # Simple CSV field parsing
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn field ->
      # Remove surrounding quotes if present
      if String.starts_with?(field, "\"") and String.ends_with?(field, "\"") do
        String.slice(field, 1..-2//1)
      else
        field
      end
    end)
  end

  @spec parse_decimal(String.t()) :: {:ok, Decimal.t()} | {:error, String.t()}
  defp parse_decimal(value) do
    case Decimal.parse(String.trim(value)) do
      {decimal, ""} -> {:ok, decimal}
      {decimal, _remainder} -> {:ok, decimal}
      :error -> {:error, "Invalid decimal: #{value}"}
    end
  end

  @spec parse_date(String.t()) :: {:ok, DateTime.t()} | {:error, String.t()}
  defp parse_date(date_str) do
    date_str = String.trim(date_str)

    # Try different date formats - most common format in the CSV is "26 Jul 2023"
    case parse_date_dd_mmm_yyyy(date_str) do
      {:ok, date} ->
        {:ok, date}

      {:error, _} ->
        # Try other common formats
        case parse_other_date_formats(date_str) do
          {:ok, date} -> {:ok, date}
          {:error, _} -> {:error, "Unable to parse date: #{date_str}"}
        end
    end
  end

  @spec parse_date_dd_mmm_yyyy(String.t()) :: {:ok, DateTime.t()} | {:error, String.t()}
  defp parse_date_dd_mmm_yyyy(date_str) do
    # Parse format like "26 Jul 2023"
    case String.split(date_str, " ") do
      [day_str, month_str, year_str] ->
        with {:ok, day} <- parse_integer(day_str),
             {:ok, month} <- parse_month_abbrev(month_str),
             {:ok, year} <- parse_integer(year_str),
             {:ok, date} <- Date.new(year, month, day),
             {:ok, datetime} <- DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
          {:ok, datetime}
        else
          _ -> {:error, "Invalid date format"}
        end

      _ ->
        {:error, "Invalid date format"}
    end
  end

  @spec parse_other_date_formats(String.t()) :: {:ok, DateTime.t()} | {:error, String.t()}
  defp parse_other_date_formats(date_str) do
    cond do
      # Try YYYY-MM-DD format
      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, date_str) ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> {:ok, DateTime.new!(date, ~T[00:00:00], "Etc/UTC")}
          _ -> {:error, "Invalid ISO date"}
        end

      # Try DD/MM/YYYY format
      Regex.match?(~r/^\d{1,2}\/\d{1,2}\/\d{4}$/, date_str) ->
        parse_date_dd_mm_yyyy(date_str)

      true ->
        {:error, "Unsupported date format"}
    end
  end

  @spec parse_date_dd_mm_yyyy(String.t()) :: {:ok, DateTime.t()} | {:error, String.t()}
  defp parse_date_dd_mm_yyyy(date_str) do
    case String.split(date_str, "/") do
      [day_str, month_str, year_str] ->
        with {:ok, day} <- parse_integer(day_str),
             {:ok, month} <- parse_integer(month_str),
             {:ok, year} <- parse_integer(year_str),
             {:ok, date} <- Date.new(year, month, day),
             {:ok, datetime} <- DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
          {:ok, datetime}
        else
          _ -> {:error, "Invalid date format"}
        end

      _ ->
        {:error, "Invalid date format"}
    end
  end

  @spec parse_integer(String.t()) :: {:ok, integer()} | {:error, String.t()}
  defp parse_integer(str) do
    case Integer.parse(String.trim(str)) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Invalid integer"}
    end
  end

  @spec parse_month_abbrev(String.t()) :: {:ok, integer()} | {:error, String.t()}
  defp parse_month_abbrev(month_str) do
    month_map = %{
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

    case Map.get(month_map, String.capitalize(month_str)) do
      nil -> {:error, "Invalid month abbreviation"}
      month -> {:ok, month}
    end
  end

  @spec find_or_create_asset(String.t()) :: {:ok, Assets.Asset.t()} | {:error, String.t()}
  defp find_or_create_asset(asset_name) do
    case Assets.get_asset_by_name(asset_name) do
      nil -> create_new_asset(asset_name)
      asset -> {:ok, asset}
    end
  end

  @spec create_new_asset(String.t()) :: {:ok, Assets.Asset.t()} | {:error, String.t()}
  defp create_new_asset(asset_name) do
    asset_attrs = %{
      name: asset_name,
      code: generate_asset_code(asset_name),
      currency: "SGD"
    }

    case Assets.create_asset(asset_attrs) do
      {:ok, asset} ->
        {:ok, asset}

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        {:error, inspect(errors)}
    end
  end

  @spec generate_asset_code(String.t()) :: String.t()
  defp generate_asset_code(name) do
    # Generate a simple code from the name
    name
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9]/, "")
    |> String.slice(0, 10)
    |> case do
      "" -> "ASSET"
      code -> code
    end
  end
end
