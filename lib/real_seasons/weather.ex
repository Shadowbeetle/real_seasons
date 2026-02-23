defmodule RealSeasons.Weather do
  @moduledoc """
  Fetches current weather data for Budapest from Open-Meteo.
  Caches responses for 5 minutes to avoid excessive API calls.
  """

  @latitude 47.498
  @longitude 19.04
  @cache_ttl_ms :timer.minutes(5)

  @forecast_url "https://api.open-meteo.com/v1/forecast"

  @type weather_data :: %{
          apparent_temperature: float(),
          time: DateTime.t()
        }

  @doc """
  Fetch the current apparent temperature for Budapest.

  Returns cached data if available and fresh, otherwise fetches from the API.
  """
  @spec fetch_current() :: {:ok, weather_data()} | {:error, term()}
  def fetch_current do
    case get_cached() do
      {:ok, data} -> {:ok, data}
      :miss -> fetch_and_cache()
    end
  end

  defp fetch_and_cache do
    case Req.get(@forecast_url,
           params: [
             latitude: @latitude,
             longitude: @longitude,
             current: "apparent_temperature",
             timezone: "Europe/Budapest"
           ]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        data = parse_response(body)
        put_cache(data)
        {:ok, data}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(%{"current" => current}) do
    apparent_temp = current["apparent_temperature"]
    time_str = current["time"]

    {:ok, naive} = NaiveDateTime.from_iso8601(time_str <> ":00")
    {:ok, datetime} = DateTime.from_naive(naive, "Europe/Budapest")

    %{
      apparent_temperature: apparent_temp,
      time: datetime
    }
  end

  defp get_cached do
    case Application.get_env(:real_seasons, :weather_cache) do
      {data, cached_at} ->
        if System.monotonic_time(:millisecond) - cached_at < @cache_ttl_ms do
          {:ok, data}
        else
          :miss
        end

      _ ->
        :miss
    end
  end

  defp put_cache(data) do
    Application.put_env(
      :real_seasons,
      :weather_cache,
      {data, System.monotonic_time(:millisecond)}
    )
  end
end
