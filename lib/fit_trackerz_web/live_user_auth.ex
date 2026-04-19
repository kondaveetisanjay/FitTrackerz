defmodule FitTrackerzWeb.LiveUserAuth do
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
      {:cont,
       socket
       |> assign(:current_user, current_user)
       |> maybe_track_notifications(current_user)}
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

  def on_mount(:live_member_required, _params, session, socket) do
    user = get_current_user(socket, session)
    role = get_user_role(user)

    if user && role in [:platform_admin, :gym_operator, :trainer, :member] do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be a member to access this page.")
       |> redirect(to: "/dashboard")}
    end
  end

  defp maybe_track_notifications(socket, user) do
    socket = assign(socket, :unread_notification_count, bell_count(user))

    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "notifications:#{user.id}")
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:user:#{user.id}")

      Phoenix.LiveView.attach_hook(
        socket,
        :notification_bell_count,
        :handle_info,
        &notification_bell_handle_info/2
      )
    else
      socket
    end
  end

  defp notification_bell_handle_info({:new_notification, _}, socket), do: {:cont, refresh_bell(socket)}
  defp notification_bell_handle_info({:notification_read, _}, socket), do: {:halt, refresh_bell(socket)}
  defp notification_bell_handle_info({:conversation_read, _}, socket), do: {:halt, refresh_bell(socket)}
  defp notification_bell_handle_info({:conversation_updated, _}, socket), do: {:cont, refresh_bell(socket)}
  defp notification_bell_handle_info({:new_message, _}, socket), do: {:cont, refresh_bell(socket)}
  defp notification_bell_handle_info(_msg, socket), do: {:cont, socket}

  defp refresh_bell(socket) do
    user = socket.assigns.current_user
    Phoenix.Component.assign(socket, :unread_notification_count, bell_count(user))
  end

  defp bell_count(user) do
    unread_notification_count(user) + unread_message_count(user)
  end

  defp unread_notification_count(user) do
    case FitTrackerz.Notifications.list_unread_notifications(user.id, actor: user) do
      {:ok, list} -> length(list)
      _ -> 0
    end
  end

  defp unread_message_count(user) do
    case FitTrackerz.Messaging.list_conversations(user.id, actor: user) do
      {:ok, conversations} ->
        Enum.reduce(conversations, 0, fn conv, acc ->
          acc + conversation_unread(conv, user.id)
        end)

      _ ->
        0
    end
  end

  defp conversation_unread(conversation, user_id) do
    participant =
      case conversation.participants do
        participants when is_list(participants) ->
          Enum.find(participants, &(&1.user_id == user_id))

        _ ->
          nil
      end

    last_read = participant && participant.last_read_at

    case conversation.messages do
      messages when is_list(messages) ->
        if last_read do
          Enum.count(messages, fn m ->
            DateTime.compare(m.inserted_at, last_read) == :gt and m.sender_id != user_id
          end)
        else
          Enum.count(messages, &(&1.sender_id != user_id))
        end

      _ ->
        0
    end
  end
end
