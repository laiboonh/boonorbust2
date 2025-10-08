defmodule Boonorbust2.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: {:ok, pid()} | {:error, term()}
  def start(_type, _args) do
    children = [
      Boonorbust2Web.Telemetry,
      Boonorbust2.Repo,
      {DNSCluster, query: Application.get_env(:boonorbust2, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Boonorbust2.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Boonorbust2.Finch},
      # Start Cachex for caching exchange rates
      {Cachex, name: :exchange_rates_cache},
      # Start a worker by calling: Boonorbust2.Worker.start_link(arg)
      # {Boonorbust2.Worker, arg},
      # Start to serve requests, typically the last entry
      Boonorbust2Web.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Boonorbust2.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  @spec config_change(keyword(), keyword(), [atom()]) :: :ok
  def config_change(changed, _new, removed) do
    Boonorbust2Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
