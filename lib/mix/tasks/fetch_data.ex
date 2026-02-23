defmodule Mix.Tasks.RealSeasons.FetchData do
  @moduledoc """
  Fetches historical weather data for Budapest and computes temperature statistics.

      mix real_seasons.fetch_data

  This fetches hourly apparent_temperature data from Open-Meteo for 1970-2025,
  caches the raw responses, and computes mean/std for each day-hour combination
  across 4 baselines. Output is written to priv/data/temps.json.
  """

  use Mix.Task

  @shortdoc "Fetch historical weather data and compute temperature stats"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("Fetching historical weather data for Budapest...")
    Mix.shell().info("This will make ~56 API requests (one per year). Be patient.")

    RealSeasons.DataPipeline.full_fetch()

    Mix.shell().info("Done! Stats written to priv/data/temps.json")
  end
end
