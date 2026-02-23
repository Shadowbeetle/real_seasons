defmodule RealSeasonsWeb.Plugs.Locale do
  @moduledoc """
  Plug that sets the Gettext locale from the session or query params.
  """
  import Plug.Conn

  @supported_locales ~w(hu en)
  @default_locale "hu"

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      conn.params["locale"] ||
        get_session(conn, :locale) ||
        locale_from_header(conn) ||
        @default_locale

    locale = if locale in @supported_locales, do: locale, else: @default_locale

    Gettext.put_locale(RealSeasonsWeb.Gettext, locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end

  defp locale_from_header(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first("")
    |> parse_accept_language()
    |> Enum.find(&(&1 in @supported_locales))
  end

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(fn part ->
      case String.split(String.trim(part), ";") do
        [lang | _] -> lang |> String.trim() |> String.split("-") |> List.first()
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
