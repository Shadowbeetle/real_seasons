defmodule RealSeasons.TempStats do
  @moduledoc """
  Loads and serves pre-computed temperature statistics (mean/std) for Budapest.

  Data is stored in Application env as a map of baseline => day_hour_key => %{mean, std}.
  """

  @data_path "priv/data/temps.json"

  @doc """
  Load temperature stats from the JSON file into Application env.
  Called at app startup from Application.start/2.
  """
  def load do
    path = Application.app_dir(:real_seasons, @data_path)

    case File.read(path) do
      {:ok, contents} ->
        data =
          contents
          |> Jason.decode!()
          |> decode_stats()

        Application.put_env(:real_seasons, :temp_stats, data)
        :ok

      {:error, :enoent} ->
        Application.put_env(:real_seasons, :temp_stats, %{})
        :ok
    end
  end

  @doc """
  Reload stats from disk. Called by the scheduler after a data refresh.
  """
  def reload, do: load()

  @doc """
  Get the mean and std for a given baseline and day-hour key.

  Returns `%{mean: float, std: float}` or `%{mean: 0.0, std: 1.0}` as fallback.
  """
  @spec get(atom(), String.t()) :: %{mean: float(), std: float()}
  def get(baseline, day_hour_key) do
    stats = Application.get_env(:real_seasons, :temp_stats, %{})
    baseline_str = Atom.to_string(baseline)

    stats
    |> Map.get(baseline_str, %{})
    |> Map.get(day_hour_key, %{mean: 0.0, std: 1.0})
  end

  @doc """
  Check if stats data has been loaded.
  """
  def loaded? do
    stats = Application.get_env(:real_seasons, :temp_stats, %{})
    map_size(stats) > 0
  end

  defp decode_stats(raw) do
    Map.new(raw, fn {baseline, entries} ->
      decoded_entries =
        Map.new(entries, fn {key, %{"mean" => mean, "std" => std}} ->
          {key, %{mean: mean, std: std}}
        end)

      {baseline, decoded_entries}
    end)
  end
end
