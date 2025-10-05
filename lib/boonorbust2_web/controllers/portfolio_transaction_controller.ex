defmodule Boonorbust2Web.PortfolioTransactionController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.PortfolioTransactions
  alias Boonorbust2.PortfolioTransactions.PortfolioTransaction

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    page = parse_page_param(params)
    filter = Map.get(params, "filter", "")
    %{id: user_id} = conn.assigns.current_user

    pagination =
      PortfolioTransactions.list_portfolio_transactions(
        page: page,
        page_size: 10,
        filter: filter,
        user_id: user_id
      )

    render(conn, :index,
      portfolio_transactions: pagination.entries,
      page_number: pagination.page_number,
      total_pages: pagination.total_pages,
      filter: filter
    )
  end

  defp parse_page_param(%{"page" => page}) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
    end
  end

  defp parse_page_param(_), do: 1

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    %{id: user_id} = conn.assigns.current_user
    portfolio_transaction = PortfolioTransactions.get_portfolio_transaction!(id, user_id)
    render(conn, :show, portfolio_transaction: portfolio_transaction)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = PortfolioTransactions.change_portfolio_transaction(PortfolioTransaction.empty())
    assets = Assets.list_assets()
    render(conn, :new, changeset: changeset, assets: assets)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"portfolio_transaction" => portfolio_transaction_params}) do
    %{id: user_id} = conn.assigns.current_user
    params = Map.put(portfolio_transaction_params, "user_id", user_id)

    case PortfolioTransactions.create_portfolio_transaction(params) do
      {:ok, portfolio_transaction} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_layout(false)
          |> render(:portfolio_transaction_item, portfolio_transaction: portfolio_transaction)
        else
          redirect(conn, to: ~p"/portfolio_transactions")
        end

      {:error, changeset} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_status(:unprocessable_entity)
          |> put_layout(false)
          |> put_view(Boonorbust2Web.CoreComponents)
          |> render(:form_errors, changeset: changeset)
        else
          assets = Assets.list_assets()
          render(conn, :new, changeset: changeset, assets: assets)
        end
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    %{id: user_id} = conn.assigns.current_user
    portfolio_transaction = PortfolioTransactions.get_portfolio_transaction!(id, user_id)
    changeset = PortfolioTransactions.change_portfolio_transaction(portfolio_transaction)
    assets = Assets.list_assets()

    render(conn, :edit,
      portfolio_transaction: portfolio_transaction,
      changeset: changeset,
      assets: assets
    )
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "portfolio_transaction" => portfolio_transaction_params}) do
    %{id: user_id} = conn.assigns.current_user
    portfolio_transaction = PortfolioTransactions.get_portfolio_transaction!(id, user_id)

    case PortfolioTransactions.update_portfolio_transaction(
           portfolio_transaction,
           portfolio_transaction_params
         ) do
      {:ok, updated_portfolio_transaction} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_layout(false)
          |> render(:portfolio_transaction_item,
            portfolio_transaction: updated_portfolio_transaction
          )
        else
          redirect(conn, to: ~p"/portfolio_transactions/#{updated_portfolio_transaction}")
        end

      {:error, changeset} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_status(:unprocessable_entity)
          |> render(:portfolio_transaction_item, portfolio_transaction: portfolio_transaction)
        else
          assets = Assets.list_assets()

          render(conn, :edit,
            portfolio_transaction: portfolio_transaction,
            changeset: changeset,
            assets: assets
          )
        end
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    %{id: user_id} = conn.assigns.current_user
    portfolio_transaction = PortfolioTransactions.get_portfolio_transaction!(id, user_id)

    {:ok, _portfolio_transaction} =
      PortfolioTransactions.delete_portfolio_transaction(portfolio_transaction)

    if get_req_header(conn, "hx-request") != [] do
      send_resp(conn, 200, "")
    else
      redirect(conn, to: ~p"/portfolio_transactions")
    end
  end

  @spec import_csv(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def import_csv(conn, %{"csv_file" => upload}) do
    case upload do
      %Plug.Upload{path: path} ->
        handle_csv_import(conn, path)

      _ ->
        handle_missing_file(conn)
    end
  end

  defp handle_csv_import(conn, path) do
    %{id: user_id} = conn.assigns.current_user

    case PortfolioTransactions.import_from_csv(path, user_id) do
      {:ok, %{success: success_count, errors: error_count, total: total_count}} ->
        message = format_success_message(success_count, error_count, total_count)
        respond_with_success(conn, message)

      {:error, reason} ->
        respond_with_error(conn, "Import failed: #{reason}")
    end
  end

  defp handle_missing_file(conn) do
    respond_with_error(conn, "No file uploaded")
  end

  defp format_success_message(success_count, error_count, total_count) do
    if error_count > 0 do
      "Imported #{success_count} of #{total_count} transactions (#{error_count} errors)"
    else
      "Successfully imported #{success_count} transactions"
    end
  end

  defp respond_with_success(conn, message) do
    conn
    |> put_layout(false)
    |> send_resp(200, message)
  end

  defp respond_with_error(conn, error_message) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_layout(false)
    |> put_view(Boonorbust2Web.CoreComponents)
    |> render(:form_errors, changeset: %{errors: [csv_file: error_message]})
  end
end
