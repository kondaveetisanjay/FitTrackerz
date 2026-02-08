defmodule FitconnexWeb.PageController do
  use FitconnexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
