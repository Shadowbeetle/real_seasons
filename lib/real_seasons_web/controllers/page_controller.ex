defmodule RealSeasonsWeb.PageController do
  use RealSeasonsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
