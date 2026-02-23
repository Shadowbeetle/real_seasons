defmodule RealSeasons.DataPipeline do
  @moduledoc """
  Fetches historical weather data from Open-Meteo and computes temperature
  statistics (mean/std) for each day-hour combination across 4 baselines.

  Used by both the Mix task (initial fetch) and the Quantum scheduler (monthly refresh).
  """

  require Logger

  @latitude 47.498
  @longitude 19.04
  @archive_url "https://archive-api.open-meteo.com/v1/archive"

  @baselines %{
    "since1970" => {1970, 2025},
    "last20y" => {2006, 2025},
    "last10y" => {2016, 2025},
    "last5y" => {2021, 2025}
  }

  @doc """
  Refresh data: fetch only the current year and recompute stats.
  Called by the Quantum scheduler.
  """
  def refresh do
    Logger.info("[DataPipeline] Starting monthly data refresh")
    current_year = Date.utc_today().year
    cache_dir = cache_dir()
    File.mkdir_p!(cache_dir)

    fetch_year(current_year, cache_dir, force: true)

    all_years = load_all_cached(cache_dir)
    stats = compute_all_baselines(all_years)
    write_output(stats)

    RealSeasons.TempStats.reload()
    Logger.info("[DataPipeline] Data refresh complete")
  end

  @doc """
  Full fetch: download all years and compute stats from scratch.
  Called by the Mix task.
  """
  def full_fetch do
    cache_dir = cache_dir()
    File.mkdir_p!(cache_dir)
    output_dir = Path.dirname(output_path())
    File.mkdir_p!(output_dir)

    {min_year, _} = @baselines |> Map.values() |> Enum.min_by(&elem(&1, 0))
    {_, max_year} = @baselines |> Map.values() |> Enum.max_by(&elem(&1, 1))

    for year <- min_year..max_year do
      fetch_year(year, cache_dir)
      Process.sleep(500)
    end

    all_years = load_all_cached(cache_dir)
    stats = compute_all_baselines(all_years)
    write_output(stats)

    Logger.info("[DataPipeline] Wrote #{output_path()}")
  end

  defp fetch_year(year, cache_dir, opts \\ []) do
    cache_file = Path.join(cache_dir, "#{year}.json")
    force = Keyword.get(opts, :force, false)

    if File.exists?(cache_file) and not force do
      Logger.info("[DataPipeline] Using cached data for #{year}")
    else
      Logger.info("[DataPipeline] Fetching data for #{year}...")

      case Req.get(@archive_url,
             params: [
               latitude: @latitude,
               longitude: @longitude,
               start_date: "#{year}-01-01",
               end_date: "#{year}-12-31",
               hourly: "apparent_temperature",
               timezone: "Europe/Budapest"
             ],
             receive_timeout: 30_000
           ) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          File.write!(cache_file, Jason.encode!(body))
          Logger.info("[DataPipeline] Cached #{year}")

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.warning("[DataPipeline] HTTP #{status} for #{year}: #{inspect(body)}")

        {:error, reason} ->
          Logger.warning("[DataPipeline] Error fetching #{year}: #{inspect(reason)}")
      end
    end
  end

  defp load_all_cached(cache_dir) do
    cache_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.map(fn filename ->
      year = filename |> String.trim_trailing(".json") |> String.to_integer()
      path = Path.join(cache_dir, filename)
      data = path |> File.read!() |> Jason.decode!()
      {year, parse_year_data(data, year)}
    end)
    |> Map.new()
  end

  defp parse_year_data(%{"hourly" => hourly}, _year) do
    times = hourly["time"]
    temps = hourly["apparent_temperature"]

    Enum.zip(times, temps)
    |> Enum.reject(fn {_time, temp} -> is_nil(temp) end)
    |> Enum.map(fn {time_str, temp} ->
      {:ok, naive} = NaiveDateTime.from_iso8601(time_str <> ":00")
      day_of_year = Date.day_of_year(NaiveDateTime.to_date(naive))
      hour = naive.hour

      day_str = day_of_year |> Integer.to_string() |> String.pad_leading(3, "0")
      hour_str = hour |> Integer.to_string() |> String.pad_leading(2, "0")

      {"#{day_str}-#{hour_str}", temp}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp parse_year_data(_data, year) do
    Logger.warning("[DataPipeline] No hourly data for #{year}")
    %{}
  end

  defp compute_all_baselines(all_years) do
    Map.new(@baselines, fn {name, {start_year, end_year}} ->
      Logger.info("[DataPipeline] Computing stats for #{name} (#{start_year}-#{end_year})")
      stats = compute_baseline(all_years, start_year, end_year)
      {name, stats}
    end)
  end

  defp compute_baseline(all_years, start_year, end_year) do
    # Collect all temps per day-hour key across the year range
    aggregated =
      for {year, year_data} <- all_years,
          year >= start_year and year <= end_year,
          {key, temps} <- year_data,
          reduce: %{} do
        acc ->
          Map.update(acc, key, temps, &(&1 ++ temps))
      end

    compute_stats(aggregated)
  end

  defp compute_stats(aggregated) do
    Map.new(aggregated, fn {key, temps} ->
      valid = Enum.reject(temps, &is_nil/1)

      if valid == [] do
        {key, %{"mean" => 0.0, "std" => 1.0}}
      else
        n = length(valid)
        sum = Enum.sum(valid)
        mean = sum / n

        variance = Enum.reduce(valid, 0.0, fn x, acc -> acc + (x - mean) * (x - mean) end) / n
        std = :math.sqrt(variance)

        {key, %{"mean" => Float.round(mean, 2), "std" => Float.round(std, 2)}}
      end
    end)
  end

  defp write_output(stats) do
    json = Jason.encode!(stats, pretty: true)
    File.write!(output_path(), json)
  end

  defp cache_dir do
    Application.app_dir(:real_seasons, "priv/data/cache")
  rescue
    # During mix tasks, app_dir may not work
    _ -> Path.join([File.cwd!(), "priv", "data", "cache"])
  end

  defp output_path do
    Application.app_dir(:real_seasons, "priv/data/temps.json")
  rescue
    _ -> Path.join([File.cwd!(), "priv", "data", "temps.json"])
  end
end
