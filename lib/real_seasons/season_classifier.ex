defmodule RealSeasons.SeasonClassifier do
  @moduledoc """
  Classifies Budapest's current weather into one of 12 humorous seasons
  based on the astrological sub-season and temperature deviation from historical baselines.
  """

  @type season ::
          :winter
          | :fools_spring
          | :second_winter
          | :deceptive_spring
          | :third_winter
          | :poplar_bloom
          | :actual_spring
          | :summer
          | :hells_porch
          | :false_fall
          | :indian_summer
          | :actual_fall

  @type temp_class :: :cold | :mid | :hot

  @type sub_season ::
          :early_spring
          | :mid_spring
          | :late_spring
          | :early_summer
          | :mid_summer
          | :late_summer
          | :early_fall
          | :mid_fall
          | :late_fall
          | :early_winter
          | :mid_winter
          | :late_winter

  @type baseline :: :since1970 | :last20y | :last10y | :last5y

  @type classification :: %{
          season: season(),
          deviations: float(),
          temp_class: temp_class(),
          sub_season: sub_season()
        }

  @seasons_ordered [
    :winter,
    :fools_spring,
    :second_winter,
    :deceptive_spring,
    :third_winter,
    :poplar_bloom,
    :actual_spring,
    :summer,
    :hells_porch,
    :false_fall,
    :indian_summer,
    :actual_fall
  ]

  @baselines [:since1970, :last20y, :last10y, :last5y]

  @sub_season_ranges [
    {:early_spring, {3, 20}, {4, 19}},
    {:mid_spring, {4, 19}, {5, 22}},
    {:late_spring, {5, 22}, {6, 21}},
    {:early_summer, {6, 21}, {7, 21}},
    {:mid_summer, {7, 21}, {8, 22}},
    {:late_summer, {8, 22}, {9, 22}},
    {:early_fall, {9, 22}, {10, 22}},
    {:mid_fall, {10, 22}, {11, 21}},
    {:late_fall, {11, 21}, {12, 21}},
    {:early_winter, {12, 21}, {1, 19}},
    {:mid_winter, {1, 19}, {2, 18}},
    {:late_winter, {2, 18}, {3, 20}}
  ]

  @std_dev_threshold 1.5

  def seasons_ordered, do: @seasons_ordered
  def baselines, do: @baselines

  @doc """
  Classify the current temperature against all 4 baselines.

  Returns a map of baseline => classification.
  """
  @spec classify_all(float(), DateTime.t()) :: %{baseline() => classification()}
  def classify_all(apparent_temp, %DateTime{} = datetime) do
    sub_season = get_sub_season(datetime)
    day_hour_key = day_hour_key(datetime)

    Map.new(@baselines, fn baseline ->
      stats = RealSeasons.TempStats.get(baseline, day_hour_key)
      classification = classify(apparent_temp, sub_season, stats)
      {baseline, classification}
    end)
  end

  @doc """
  Classify temperature given a sub-season and baseline stats.
  """
  @spec classify(float(), sub_season(), %{mean: float(), std: float()}) :: classification()
  def classify(apparent_temp, sub_season, %{mean: mean, std: std}) do
    deviations = if std > 0, do: (apparent_temp - mean) / std, else: 0.0
    temp_class = classify_temp(apparent_temp, mean, std)
    season = lookup_season(sub_season, temp_class)

    %{
      season: season,
      deviations: deviations,
      temp_class: temp_class,
      sub_season: sub_season
    }
  end

  @doc """
  Compute the day-hour key ("DDD-HH") for a DateTime in Budapest timezone.
  """
  @spec day_hour_key(DateTime.t()) :: String.t()
  def day_hour_key(%DateTime{} = datetime) do
    budapest_dt = DateTime.shift_zone!(datetime, "Europe/Budapest")
    day_of_year = Date.day_of_year(DateTime.to_date(budapest_dt))
    hour = budapest_dt.hour

    day_str = day_of_year |> Integer.to_string() |> String.pad_leading(3, "0")
    hour_str = hour |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{day_str}-#{hour_str}"
  end

  @doc """
  Determine the astrological sub-season for a given datetime.
  """
  @spec get_sub_season(DateTime.t()) :: sub_season()
  def get_sub_season(%DateTime{} = datetime) do
    budapest_dt = DateTime.shift_zone!(datetime, "Europe/Budapest")
    month = budapest_dt.month
    day = budapest_dt.day

    find_sub_season(month, day)
  end

  defp find_sub_season(month, day) do
    date_tuple = {month, day}

    Enum.find_value(@sub_season_ranges, fn {name, start_md, end_md} ->
      if in_range?(date_tuple, start_md, end_md), do: name
    end)
  end

  # earlyWinter wraps around the year boundary (Dec 21 → Jan 19)
  defp in_range?(date, {start_m, start_d}, {end_m, end_d}) when start_m > end_m do
    date >= {start_m, start_d} or date < {end_m, end_d}
  end

  defp in_range?(date, {start_m, start_d}, {end_m, end_d}) do
    date >= {start_m, start_d} and date < {end_m, end_d}
  end

  defp classify_temp(temp, mean, std) do
    cond do
      temp < mean - @std_dev_threshold * std -> :cold
      temp > mean + @std_dev_threshold * std -> :hot
      true -> :mid
    end
  end

  # Season grid: sub_season × temp_class → season
  # Winter sub-seasons
  defp lookup_season(:early_winter, :cold), do: :winter
  defp lookup_season(:early_winter, :mid), do: :winter
  defp lookup_season(:early_winter, :hot), do: :fools_spring
  defp lookup_season(:mid_winter, :cold), do: :winter
  defp lookup_season(:mid_winter, :mid), do: :winter
  defp lookup_season(:mid_winter, :hot), do: :fools_spring
  defp lookup_season(:late_winter, :cold), do: :second_winter
  defp lookup_season(:late_winter, :mid), do: :second_winter
  defp lookup_season(:late_winter, :hot), do: :fools_spring

  # Spring sub-seasons
  defp lookup_season(:early_spring, :cold), do: :third_winter
  defp lookup_season(:early_spring, :mid), do: :deceptive_spring
  defp lookup_season(:early_spring, :hot), do: :deceptive_spring
  defp lookup_season(:mid_spring, :cold), do: :third_winter
  defp lookup_season(:mid_spring, :mid), do: :actual_spring
  defp lookup_season(:mid_spring, :hot), do: :poplar_bloom
  defp lookup_season(:late_spring, :cold), do: :third_winter
  defp lookup_season(:late_spring, :mid), do: :actual_spring
  defp lookup_season(:late_spring, :hot), do: :poplar_bloom

  # Summer sub-seasons
  defp lookup_season(:early_summer, :cold), do: :summer
  defp lookup_season(:early_summer, :mid), do: :summer
  defp lookup_season(:early_summer, :hot), do: :hells_porch
  defp lookup_season(:mid_summer, :cold), do: :summer
  defp lookup_season(:mid_summer, :mid), do: :summer
  defp lookup_season(:mid_summer, :hot), do: :hells_porch
  defp lookup_season(:late_summer, :cold), do: :false_fall
  defp lookup_season(:late_summer, :mid), do: :false_fall
  defp lookup_season(:late_summer, :hot), do: :hells_porch

  # Fall sub-seasons
  defp lookup_season(:early_fall, :cold), do: :winter
  defp lookup_season(:early_fall, :mid), do: :actual_fall
  defp lookup_season(:early_fall, :hot), do: :indian_summer
  defp lookup_season(:mid_fall, :cold), do: :winter
  defp lookup_season(:mid_fall, :mid), do: :actual_fall
  defp lookup_season(:mid_fall, :hot), do: :indian_summer
  defp lookup_season(:late_fall, :cold), do: :winter
  defp lookup_season(:late_fall, :mid), do: :actual_fall
  defp lookup_season(:late_fall, :hot), do: :indian_summer
end
