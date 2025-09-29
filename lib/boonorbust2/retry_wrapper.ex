defmodule Boonorbust2.RetryWrapper do
  @moduledoc """
  A module that automatically wraps all functions with retry logic using @on_definition.

  When `use Boonorbust2.RetryWrapper` is added to a module, all public functions
  will be automatically wrapped with exponential backoff retry logic that rescues
  DBConnection.ConnectionError exceptions.
  """

  # 1. The __using__ macro simply imports the required module and sets the hook.
  defmacro __using__(_) do
    quote do
      # Make the Retry macros available
      use Retry
      # Register the @on_definition hook
      @on_definition {Boonorbust2.RetryWrapper, :handle_definition}
      @before_compile {Boonorbust2.RetryWrapper, :__before_compile__}

      Module.register_attribute(__MODULE__, :retry_wrapped_defs, accumulate: true)
    end
  end

  def handle_definition(env, :def, name, args, guards, body) do
    # Skip special functions
    if name not in [:__info__, :__using__, :__before_compile__] do
      # Create wrapped body with retry logic
      wrapped_body =
        quote do
          retry with: exponential_backoff() |> randomize() |> expiry(10_000),
                rescue_only: [DBConnection.ConnectionError] do
            unquote(body)
          after
            result -> result
          else
            error -> error
          end
        end

      # Store the wrapped definition for later replacement
      Module.put_attribute(env.module, :retry_wrapped_defs, {name, args, guards, wrapped_body})
    end
  end

  def handle_definition(_env, _kind, _name, _args, _guards, _body), do: :ok

  defmacro __before_compile__(env) do
    wrapped_defs = Module.get_attribute(env.module, :retry_wrapped_defs) || []

    # Get the function signatures for defoverridable
    function_sigs =
      Enum.map(wrapped_defs, fn {name, args, _guards, _body} ->
        {name, length(args)}
      end)
      |> Enum.uniq()

    wrapped_definitions =
      for {name, args, guards, body} <- wrapped_defs do
        if guards == [] do
          quote do
            def unquote(name)(unquote_splicing(args)) do
              unquote(body)
            end
          end
        else
          quote do
            def unquote(name)(unquote_splicing(args)) when unquote_splicing(guards) do
              unquote(body)
            end
          end
        end
      end

    if function_sigs != [] do
      quote do
        defoverridable unquote(function_sigs)
        unquote_splicing(wrapped_definitions)
      end
    else
      quote do
      end
    end
  end
end
