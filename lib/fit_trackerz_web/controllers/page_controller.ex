defmodule FitTrackerzWeb.PageController do
  use FitTrackerzWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def solutions_members(conn, _params) do
    render(conn, :solutions_members)
  end

  def solutions_trainers(conn, _params) do
    render(conn, :solutions_trainers)
  end

  def solutions_operators(conn, _params) do
    render(conn, :solutions_operators)
  end

  def redirect_to_dashboard(conn, _params) do
    target =
      case conn.request_path do
        "/member" -> "/member/dashboard"
        "/trainer" -> "/trainer/dashboard"
        "/gym" -> "/gym/dashboard"
        "/admin" -> "/admin/dashboard"
        _ -> "/dashboard"
      end

    conn |> redirect(to: target) |> halt()
  end
end
