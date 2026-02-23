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
        @default_locale

    locale = if locale in @supported_locales, do: locale, else: @default_locale

    Gettext.put_locale(RealSeasonsWeb.Gettext, locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end
end
