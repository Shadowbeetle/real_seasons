defmodule RealSeasons.Repo do
  use Ecto.Repo,
    otp_app: :real_seasons,
    adapter: Ecto.Adapters.Postgres
end
