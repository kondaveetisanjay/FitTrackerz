defmodule FitconnexWeb.AuthController do
  use FitconnexWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, token) do
    {redirect_path, flash_msg} = redirect_for_user(user, activity)

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

  def failure(conn, activity, reason) do
    {redirect_path, message} = failure_details(activity, reason)

    conn
    |> put_flash(:error, message)
    |> redirect(to: redirect_path)
  end

  defp failure_details(activity, reason) when is_tuple(activity) do
    case activity do
      {:password, :register} ->
        message = extract_error_message(reason, "Registration failed. Please try again.")
        {~p"/register", message}

      _ ->
        {~p"/sign-in", "Invalid email or password."}
    end
  end

  defp failure_details(_activity, _reason) do
    {~p"/sign-in", "Invalid email or password."}
  end

  defp extract_error_message(reason, default) do
    errors =
      case reason do
        %{errors: errors} when is_list(errors) -> errors
        _ -> []
      end

    cond do
      Enum.any?(errors, fn e ->
        match?(%{field: :email}, e) and
          String.contains?(to_string(Map.get(e, :message, "")), "already")
      end) ->
        "An account with this email already exists. Please sign in instead."

      match?([%{message: msg} | _] when is_binary(msg), errors) ->
        [%{message: msg} | _] = errors
        msg

      true ->
        default
    end
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
      |> put_flash(:info, "Role updated! Welcome to FITTRACKRPRO.")
      |> redirect(to: dashboard_path_for_role(user.role))
    end
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:fitconnex)
    |> put_flash(:info, "You have been signed out.")
    |> redirect(to: ~p"/")
  end

  defp redirect_for_user(user, activity) do
    if registration?(activity) do
      {~p"/choose-role", "Account created! Please choose your role."}
    else
      {dashboard_path_for_role(user.role), "Welcome back, #{user.name}!"}
    end
  end

  defp registration?({:password, :register}), do: true
  defp registration?({_, :register_with_password}), do: true
  defp registration?(_), do: false

  defp dashboard_path_for_role(:platform_admin), do: "/admin/dashboard"
  defp dashboard_path_for_role(:gym_operator), do: "/gym/dashboard"
  defp dashboard_path_for_role(:member), do: "/member/dashboard"
  defp dashboard_path_for_role(_), do: "/member/dashboard"
end
