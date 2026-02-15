defmodule Boonorbust2Web.PortfolioTransactionLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Assets
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.PortfolioTransactions
  alias Boonorbust2.PortfolioTransactions.PortfolioTransaction

  @impl true
  def mount(_params, _session, socket) do
    %{id: user_id} = socket.assigns.current_user

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:form_errors, nil)
      |> assign(:transaction_in_progress, nil)
      |> assign(:csv_modal_open, false)
      |> assign(:csv_result, nil)
      |> assign(:filter, "")
      |> assign(:page, 1)
      |> allow_upload(:csv_file, accept: [".csv"], max_entries: 1)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    %{user_id: user_id, filter: filter, page: page} = socket.assigns

    pagination =
      PortfolioTransactions.list_portfolio_transactions(
        page: page,
        page_size: 10,
        filter: filter,
        user_id: user_id
      )

    socket =
      socket
      |> assign(:assets, Assets.list_assets())
      |> assign(:page_number, pagination.page_number)
      |> assign(:total_pages, pagination.total_pages)
      |> stream(:transactions, pagination.entries, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply,
     assign(socket,
       transaction_in_progress: %{
         id: nil,
         asset_id: nil,
         action: nil,
         quantity: nil,
         price: nil,
         commission: nil,
         transaction_date: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:%M"),
         notes: nil
       },
       form_errors: nil
     )}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    %{user_id: user_id} = socket.assigns
    transaction = PortfolioTransactions.get_portfolio_transaction!(id, user_id)

    {:noreply,
     assign(socket,
       transaction_in_progress: %{
         id: transaction.id,
         asset_id: transaction.asset_id,
         action: transaction.action,
         quantity: Decimal.to_string(transaction.quantity),
         price: Decimal.to_string(transaction.price.amount),
         commission: Decimal.to_string(transaction.commission.amount),
         transaction_date:
           DateTime.to_naive(transaction.transaction_date) |> NaiveDateTime.to_iso8601(),
         notes: transaction.notes
       },
       form_errors: nil
     )}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, transaction_in_progress: nil, form_errors: nil)}
  end

  def handle_event("save", %{"transaction" => transaction_params}, socket) do
    %{user_id: user_id} = socket.assigns
    params = transaction_params |> normalize_params() |> Map.put("user_id", user_id)

    case PortfolioTransactions.create_portfolio_transaction(params) do
      {:ok, transaction} ->
        handle_create_success(socket, transaction, transaction_params)

      {:error, changeset} ->
        {:noreply, assign_form_error(socket, changeset, transaction_params)}
    end
  end

  def handle_event(
        "update",
        %{"transaction_id" => id, "transaction" => transaction_params},
        socket
      ) do
    %{user_id: user_id} = socket.assigns
    transaction = PortfolioTransactions.get_portfolio_transaction!(id, user_id)

    case PortfolioTransactions.update_portfolio_transaction(
           transaction,
           normalize_params(transaction_params)
         ) do
      {:ok, updated_transaction} ->
        handle_update_success(socket, transaction, updated_transaction, transaction_params)

      {:error, changeset} ->
        {:noreply, assign_form_error(socket, changeset, transaction_params)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    %{user_id: user_id} = socket.assigns
    transaction = PortfolioTransactions.get_portfolio_transaction!(id, user_id)
    asset_id = transaction.asset_id

    {:ok, _} = PortfolioTransactions.delete_portfolio_transaction(transaction)
    recalculate_positions(asset_id, user_id)

    socket =
      socket
      |> stream_delete(:transactions, %PortfolioTransaction{id: transaction.id})

    {:noreply, socket}
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:page, 1)
      |> reload_transactions()

    {:noreply, socket}
  end

  def handle_event("clear_filter", _params, socket) do
    socket =
      socket
      |> assign(:filter, "")
      |> assign(:page, 1)
      |> reload_transactions()

    {:noreply, socket}
  end

  def handle_event("page", %{"page" => page}, socket) do
    {page, _} = Integer.parse(page)

    socket =
      socket
      |> assign(:page, page)
      |> reload_transactions()

    {:noreply, socket}
  end

  def handle_event("open_csv_modal", _params, socket) do
    {:noreply, assign(socket, csv_modal_open: true, csv_result: nil)}
  end

  def handle_event("close_csv_modal", _params, socket) do
    {:noreply, assign(socket, csv_modal_open: false, csv_result: nil)}
  end

  def handle_event("validate_csv", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("import_csv", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        dest = Path.join(System.tmp_dir!(), "csv_upload_#{System.unique_integer()}.csv")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    case uploaded_files do
      [file_path] -> {:noreply, process_csv_import(socket, file_path)}
      [] -> {:noreply, assign(socket, csv_result: {:error, "No file uploaded"})}
    end
  end

  defp handle_create_success(socket, transaction, transaction_params) do
    %{user_id: user_id} = socket.assigns

    case recalculate_positions(transaction.asset_id, user_id) do
      :ok ->
        socket =
          socket
          |> assign(:transaction_in_progress, nil)
          |> assign(:form_errors, nil)
          |> stream_insert(:transactions, transaction, at: 0)

        {:noreply, socket}

      {:error, message} ->
        PortfolioTransactions.delete_portfolio_transaction(transaction)
        {:noreply, assign_position_error(socket, message, transaction_params)}
    end
  end

  defp handle_update_success(socket, original, updated, transaction_params) do
    %{user_id: user_id} = socket.assigns

    case recalculate_positions(updated.asset_id, user_id) do
      :ok ->
        socket =
          socket
          |> assign(:transaction_in_progress, nil)
          |> assign(:form_errors, nil)
          |> stream_insert(:transactions, updated)

        {:noreply, socket}

      {:error, message} ->
        revert_attrs =
          original
          |> Map.from_struct()
          |> Map.drop([:__meta__, :user, :asset])
          |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)

        PortfolioTransactions.update_portfolio_transaction(updated, revert_attrs)
        {:noreply, assign_position_error(socket, message, transaction_params)}
    end
  end

  defp assign_form_error(socket, changeset, transaction_params) do
    assign(socket,
      form_errors: changeset,
      transaction_in_progress:
        preserve_transaction_input(socket.assigns.transaction_in_progress, transaction_params)
    )
  end

  defp process_csv_import(socket, file_path) do
    %{user_id: user_id} = socket.assigns

    case PortfolioTransactions.import_from_csv(file_path, user_id) do
      {:ok,
       %{
         success: success_count,
         errors: error_count,
         total: total_count,
         affected_asset_ids: asset_ids
       }} ->
        Enum.each(asset_ids, &recalculate_positions(&1, user_id))

        message =
          PortfolioTransactions.format_import_result_message(
            success_count,
            error_count,
            total_count
          )

        File.rm(file_path)

        socket
        |> assign(:csv_result, {:ok, message})
        |> reload_transactions()

      {:error, reason} ->
        File.rm(file_path)
        assign(socket, csv_result: {:error, "Import failed: #{reason}"})
    end
  end

  defp assign_position_error(socket, message, transaction_params) do
    changeset =
      PortfolioTransaction.empty()
      |> PortfolioTransactions.change_portfolio_transaction()
      |> Ecto.Changeset.add_error(:base, message)

    assign(socket,
      form_errors: changeset,
      transaction_in_progress:
        preserve_transaction_input(socket.assigns.transaction_in_progress, transaction_params)
    )
  end

  defp recalculate_positions(asset_id, user_id) do
    PortfolioPositions.calculate_and_upsert_positions_for_asset(asset_id, user_id)
    :ok
  rescue
    e in ArgumentError ->
      {:error, e.message}
  end

  defp reload_transactions(socket) do
    %{user_id: user_id, filter: filter, page: page} = socket.assigns

    pagination =
      PortfolioTransactions.list_portfolio_transactions(
        page: page,
        page_size: 10,
        filter: filter,
        user_id: user_id
      )

    socket
    |> assign(:page_number, pagination.page_number)
    |> assign(:total_pages, pagination.total_pages)
    |> stream(:transactions, pagination.entries, reset: true)
  end

  # Normalize empty strings to nil to avoid cast errors
  defp normalize_params(params) do
    Enum.into(params, %{}, fn
      {key, ""} -> {key, nil}
      {key, value} -> {key, value}
    end)
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files"

  defp preserve_transaction_input(current, params) do
    %{
      id: current.id,
      asset_id: Map.get(params, "asset_id", current.asset_id),
      action: Map.get(params, "action", current.action),
      quantity: Map.get(params, "quantity", current.quantity),
      price: Map.get(params, "price", current.price),
      commission: Map.get(params, "commission", current.commission),
      transaction_date: Map.get(params, "transaction_date", current.transaction_date),
      notes: Map.get(params, "notes", current.notes)
    }
  end
end
