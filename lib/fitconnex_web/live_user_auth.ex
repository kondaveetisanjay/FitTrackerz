defmodule FitconnexWeb.LiveUserAuth do
  @moduledoc """
  LiveView on_mount hooks for authentication and authorization.
  """
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  defp get_current_user(socket, session) do
    case socket.assigns[:current_user] do
      nil ->
        case session["current_user"] do
          %{} = user -> atomize_keys(user)
          _ -> nil
        end

      user ->
        user
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp get_user_role(user) when is_struct(user), do: user.role
  defp get_user_role(%{"role" => role}) when is_binary(role), do: String.to_existing_atom(role)
  defp get_user_role(%{"role" => role}) when is_atom(role), do: role
  defp get_user_role(%{role: role}) when is_binary(role), do: String.to_existing_atom(role)
  defp get_user_role(%{role: role}) when is_atom(role), do: role
  defp get_user_role(_), do: nil

  def on_mount(:live_user_required, _params, session, socket) do
    current_user = get_current_user(socket, session)

    if current_user do
      {:cont, assign(socket, :current_user, current_user)}
    else
      {:halt, redirect(socket, to: "/sign-in")}
    end
  end

  def on_mount(:live_user_optional, _params, session, socket) do
    {:cont, assign(socket, :current_user, get_current_user(socket, session))}
  end

  def on_mount(:live_no_user, _params, session, socket) do
    if get_current_user(socket, session) do
      {:halt, redirect(socket, to: "/dashboard")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:live_admin_required, _params, session, socket) do
    user = get_current_user(socket, session)
    role = get_user_role(user)

    if user && role == :platform_admin do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be a platform admin to access this page.")
       |> redirect(to: "/dashboard")}
    end
  end

  def on_mount(:live_gym_operator_required, _params, session, socket) do
    user = get_current_user(socket, session)
    role = get_user_role(user)

    if user && role in [:platform_admin, :gym_operator] do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be a gym operator to access this page.")
       |> redirect(to: "/dashboard")}
    end
  end

  def on_mount(:live_trainer_required, _params, session, socket) do
    user = get_current_user(socket, session)
    role = get_user_role(user)

    if user && role in [:platform_admin, :gym_operator, :trainer] do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be a trainer to access this page.")
       |> redirect(to: "/dashboard")}
    end
  end
end
