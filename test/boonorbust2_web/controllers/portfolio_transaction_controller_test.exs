defmodule Boonorbust2Web.PortfolioTransactionControllerTest do
  use Boonorbust2Web.ConnCase, async: false

  alias Boonorbust2.PortfolioTransactions

  describe "import_csv/2 - message formatting with context function" do
    setup do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          uid: "test123",
          currency: "USD"
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> assign(:current_user, user)

      {:ok, conn: conn, user: user}
    end

    test "context function formats success message correctly when all imports succeed" do
      # Test the context function directly
      message = PortfolioTransactions.format_import_result_message(5, 0, 5)
      assert message == "Successfully imported 5 transactions"
    end

    test "context function formats message with error count when some imports fail" do
      # Test the context function directly
      message = PortfolioTransactions.format_import_result_message(3, 2, 5)
      assert message == "Imported 3 of 5 transactions (2 errors)"
    end

    test "context function formats message correctly when all imports fail" do
      # Test the context function directly
      message = PortfolioTransactions.format_import_result_message(0, 5, 5)
      assert message == "Imported 0 of 5 transactions (5 errors)"
    end

    test "verifies message formatting has been moved from controller to context" do
      # Verify the controller no longer has the format_success_message function
      refute function_exported?(
               Boonorbust2Web.PortfolioTransactionController,
               :format_success_message,
               3
             )

      # Verify the context has the formatting function
      assert function_exported?(
               Boonorbust2.PortfolioTransactions,
               :format_import_result_message,
               3
             )
    end
  end
end
