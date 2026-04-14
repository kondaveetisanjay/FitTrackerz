defmodule FitTrackerzWeb.Member.NotificationsLive do
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

  defp notification_icon(:subscription_expiring), do: "hero-clock-solid"
  defp notification_icon(:subscription_expired), do: "hero-exclamation-triangle-solid"
  defp notification_icon(:payment_due), do: "hero-currency-rupee-solid"
  defp notification_icon(:payment_received), do: "hero-check-circle-solid"
  defp notification_icon(:invitation_received), do: "hero-envelope-solid"
  defp notification_icon(:plan_assigned), do: "hero-credit-card-solid"
  defp notification_icon(_), do: "hero-bell-solid"

  defp notification_color(:subscription_expiring), do: "text-warning"
  defp notification_color(:subscription_expired), do: "text-error"
  defp notification_color(:payment_due), do: "text-warning"
  defp notification_color(:payment_received), do: "text-success"
  defp notification_color(:invitation_received), do: "text-info"
  defp notification_color(:plan_assigned), do: "text-primary"
  defp notification_color(_), do: "text-base-content/50"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Notifications" subtitle="Stay updated on your subscriptions and gym activity." back_path="/member">
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
          subtitle="You're all caught up! We'll notify you about subscription updates and gym activity."
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
