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

  def solutions_operators(conn, _params) do
    render(conn, :solutions_operators)
  end
end
