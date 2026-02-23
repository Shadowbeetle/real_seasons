defmodule RealSeasonsWeb.PageControllerTest do
  use RealSeasonsWeb.ConnCase

  test "GET / renders the home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "season-list"
  end

  test "GET /locale/:locale sets locale and redirects", %{conn: conn} do
    conn = get(conn, ~p"/locale/en")
    assert redirected_to(conn) == "/"

    conn = get(conn, ~p"/locale/hu")
    assert redirected_to(conn) == "/"
  end
end
