defmodule FitconnexWeb.AuthController do
  use FitconnexWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, token) do
    {redirect_path, flash_msg} = redirect_for_user(user)

    conn
    |> store_in_session(user)
    |> put_session(:current_user, %{
      "id" => user.id,
      "email" => to_string(user.email),
      "name" => user.name,
      "role" => to_string(user.role)
    })
    |> put_session(:user_auth, token)
    |> assign(:current_user, user)
    |> put_flash(:info, flash_msg)
    |> redirect(to: redirect_path)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Invalid email or password.")
    |> redirect(to: ~p"/sign-in")
  end

  def role_selected(conn, _params) do
    user = conn.assigns[:current_user]

    if is_nil(user) do
      conn
      |> put_flash(:error, "You must be signed in.")
      |> redirect(to: ~p"/sign-in")
    else
      conn
      |> put_session(:current_user, %{
        "id" => user.id,
        "email" => to_string(user.email),
        "name" => user.name,
        "role" => to_string(user.role)
      })
      |> put_flash(:info, "Role updated! Welcome to FitConnex.")
      |> redirect(to: dashboard_path_for_role(user.role))
    end
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:fitconnex)
    |> put_flash(:info, "You have been signed out.")
    |> redirect(to: ~p"/")
  end

  defp redirect_for_user(user) do
    if new_user?(user) do
      {~p"/choose-role", "Account created! Please choose your role."}
    else
      {dashboard_path_for_role(user.role), "Welcome back, #{user.name}!"}
    end
  end

  defp new_user?(user) do
    user.role == :member && user.inserted_at == user.updated_at
  end

  defp dashboard_path_for_role(:platform_admin), do: "/admin/dashboard"
  defp dashboard_path_for_role(:gym_operator), do: "/gym/dashboard"
  defp dashboard_path_for_role(:trainer), do: "/trainer/dashboard"
  defp dashboard_path_for_role(:member), do: "/member/dashboard"
  defp dashboard_path_for_role(_), do: "/member/dashboard"
end
