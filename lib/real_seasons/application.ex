defmodule RealSeasons.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    RealSeasons.TempStats.load()

    children = [
      RealSeasonsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:real_seasons, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RealSeasons.PubSub},
      RealSeasons.Scheduler,
      RealSeasonsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RealSeasons.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RealSeasonsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
