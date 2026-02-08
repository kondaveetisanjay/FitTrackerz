defmodule FitconnexWeb.PageController do
  use FitconnexWeb, :controller

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
end
