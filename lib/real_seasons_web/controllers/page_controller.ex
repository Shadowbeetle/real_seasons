defmodule RealSeasonsWeb.PageController do
  use RealSeasonsWeb, :controller

  alias RealSeasons.SeasonClassifier
  alias RealSeasons.Weather

  @season_names %{
    winter: "Winter",
    fools_spring: "Fool's Spring",
    second_winter: "Second Winter",
    deceptive_spring: "Deceptive Spring",
    third_winter: "Third Winter",
    poplar_bloom: "The Poplar Bloom",
    actual_spring: "Actual Spring",
    summer: "Summer",
    hells_porch: "Hell's Front Porch",
    false_fall: "False Fall",
    indian_summer: "Indian Summer",
    actual_fall: "Actual Fall"
  }

  @season_icons %{
    winter: "hero-cloud-mini",
    fools_spring: "hero-sun-mini",
    second_winter: "hero-cloud-mini",
    deceptive_spring: "hero-eye-mini",
    third_winter: "hero-cloud-mini",
    poplar_bloom: "hero-sparkles-mini",
    actual_spring: "hero-sun-mini",
    summer: "hero-fire-mini",
    hells_porch: "hero-fire-mini",
    false_fall: "hero-cloud-mini",
    indian_summer: "hero-sun-mini",
    actual_fall: "hero-cloud-mini"
  }

  @baseline_labels %{
    since1970: "Since 1970",
    last20y: "Last 20 years",
    last10y: "Last 10 years",
    last5y: "Last 5 years"
  }

  @baseline_colors %{
    since1970: "bg-red-500",
    last20y: "bg-orange-400",
    last10y: "bg-blue-500",
    last5y: "bg-emerald-500"
  }

  def home(conn, _params) do
    # Pre-translate dynamic strings (avoids gettext macro warnings for non-literal args)
    translated_season_names = translate_map(@season_names)
    translated_baseline_labels = translate_map(@baseline_labels)

    common_assigns = [
      seasons_ordered: SeasonClassifier.seasons_ordered(),
      baselines: SeasonClassifier.baselines(),
      season_names: translated_season_names,
      season_icons: @season_icons,
      baseline_labels: translated_baseline_labels,
      baseline_colors: @baseline_colors,
      data_loaded: RealSeasons.TempStats.loaded?()
    ]

    case Weather.fetch_current() do
      {:ok, weather} ->
        classifications =
          SeasonClassifier.classify_all(weather.apparent_temperature, weather.time)

        primary = classifications[:since1970]

        render(
          conn,
          :home,
          [{:weather, weather}, {:classifications, classifications}, {:primary, primary}] ++
            common_assigns
        )

      {:error, reason} ->
        render(
          conn,
          :home,
          [{:weather, nil}, {:classifications, %{}}, {:primary, nil}, {:error, reason}] ++
            common_assigns
        )
    end
  end

  defp translate_map(map) do
    Map.new(map, fn {key, msgid} ->
      {key, Gettext.gettext(RealSeasonsWeb.Gettext, msgid)}
    end)
  end

  def set_locale(conn, %{"locale" => locale}) do
    conn
    |> put_session(:locale, locale)
    |> redirect(to: ~p"/")
  end
end
