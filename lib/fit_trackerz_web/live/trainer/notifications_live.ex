defmodule FitTrackerzWeb.Trainer.NotificationsLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "notifications:#{actor.id}")
    end

    notifications = load_notifications(actor)

    {:ok,
     assign(socket,
       page_title: "Notifications",
       notifications: notifications
     )}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    notification = Enum.find(socket.assigns.notifications, &(&1.id == id))

    if notification do
      case FitTrackerz.Notifications.mark_notification_read(notification, actor: actor) do
        {:ok, _} ->
          Phoenix.PubSub.broadcast(
            FitTrackerz.PubSub,
            "notifications:#{actor.id}",
            {:notification_read, id}
          )
          notifications = load_notifications(actor)
          {:noreply, assign(socket, notifications: notifications)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to mark notification as read.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    actor = socket.assigns.current_user

    unread = Enum.filter(socket.assigns.notifications, &(!&1.is_read))

    Enum.each(unread, fn n ->
      FitTrackerz.Notifications.mark_notification_read(n, actor: actor)
    end)

    if unread != [] do
      Phoenix.PubSub.broadcast(
        FitTrackerz.PubSub,
        "notifications:#{actor.id}",
        {:notification_read, :all}
      )
    end

    notifications = load_notifications(actor)
    {:noreply, assign(socket, notifications: notifications)}
  end

  @impl true
  def handle_info({:new_notification, _payload}, socket) do
    notifications = load_notifications(socket.assigns.current_user)
    {:noreply, assign(socket, notifications: notifications)}
  end

  defp load_notifications(actor) do
    case FitTrackerz.Notifications.list_notifications(actor.id, actor: actor) do
      {:ok, notifications} -> notifications
      _ -> []
    end
  end

  defp notification_icon(:assignment_request), do: "hero-user-plus-solid"
  defp notification_icon(:invitation_received), do: "hero-envelope-solid"
  defp notification_icon(:plan_assigned), do: "hero-credit-card-solid"
  defp notification_icon(_), do: "hero-bell-solid"

  defp notification_color(:assignment_request), do: "text-primary"
  defp notification_color(:invitation_received), do: "text-info"
  defp notification_color(:plan_assigned), do: "text-primary"
  defp notification_color(_), do: "text-base-content/50"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="Notifications" subtitle="Client assignment requests and activity updates." back_path="/trainer/dashboard">
        <:actions>
          <%= if Enum.any?(@notifications, &(!&1.is_read)) do %>
            <.button variant="ghost" size="sm" icon="hero-check" phx-click="mark_all_read" id="mark-all-read-btn">
              Mark all as read
            </.button>
          <% end %>
        </:actions>
      </.page_header>

      <%= if @notifications == [] do %>
        <.empty_state
          icon="hero-bell-slash"
          title="No Notifications"
          subtitle="You're all caught up! We'll notify you when you get new client assignment requests or updates."
        />
      <% else %>
        <div class="space-y-3" id="notifications-list">
          <div
            :for={notification <- @notifications}
            id={"notification-#{notification.id}"}
          >
            <.card class={if notification.is_read, do: "opacity-60", else: "border-primary/20"}>
              <div class="flex items-start gap-4">
                <div class={"w-10 h-10 rounded-xl flex items-center justify-center shrink-0 #{if notification.is_read, do: "bg-base-300/30", else: "bg-primary/10"}"}>
                  <.icon
                    name={notification_icon(notification.type)}
                    class={"size-5 #{notification_color(notification.type)}"}
                  />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-start justify-between gap-2">
                    <div>
                      <h3 class={"text-sm font-semibold #{unless notification.is_read, do: "text-base-content", else: "text-base-content/70"}"}>
                        {notification.title}
                      </h3>
                      <p class="text-sm text-base-content/60 mt-0.5">{notification.message}</p>
                      <p class="text-xs text-base-content/40 mt-1">{format_time(notification.inserted_at)}</p>
                    </div>
                    <%= unless notification.is_read do %>
                      <.button
                        variant="ghost"
                        size="sm"
                        icon="hero-check"
                        phx-click="mark_read"
                        phx-value-id={notification.id}
                      >
                      </.button>
                    <% end %>
                  </div>
                </div>
              </div>
            </.card>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
