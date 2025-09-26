[
  # Add any dialyzer warnings you want to ignore here
  # Example:
  # ~r/.*this function has no local return.*/,
  # {":0:unknown_function Function 'Elixir.SuperModule':'some_func'/0 does not exist", :unknown_function}

  # Authentication plug halts connection when auth fails - this is expected behavior
  ~r/Function require_authenticated_user\/2 has no local return/
]
