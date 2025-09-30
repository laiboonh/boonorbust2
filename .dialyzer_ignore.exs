[
  # Add any dialyzer warnings you want to ignore here
  # Example:
  # ~r/.*this function has no local return.*/,
  # {":0:unknown_function Function 'Elixir.SuperModule':'some_func'/0 does not exist", :unknown_function}

  # Authentication plug halts connection when auth fails - this is expected behavior
  ~r/Function require_authenticated_user\/2 has no local return/

  # # Portfolio transactions - Ecto patterns that work correctly but Dialyzer doesn't understand
  # ~r/lib\/boonorbust2\/portfolio_transactions\.ex.+invalid_contract/,
  # ~r/lib\/boonorbust2\/portfolio_transactions\.ex.+no_return/,
  # ~r/lib\/boonorbust2\/portfolio_transactions\.ex.+call/,
  # ~r/lib\/boonorbust2_web\/controllers\/portfolio_transaction_controller\.ex.+invalid_contract/,
  # ~r/lib\/boonorbust2_web\/controllers\/portfolio_transaction_controller\.ex.+no_return/,
  # ~r/lib\/boonorbust2_web\/controllers\/portfolio_transaction_controller\.ex.+call/
]
