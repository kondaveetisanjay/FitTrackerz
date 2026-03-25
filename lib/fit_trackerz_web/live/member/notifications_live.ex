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
      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">Notifications</h1>
              <p class="text-base-content/50 mt-1">Stay updated on your subscriptions and gym activity.</p>
            </div>
          </div>
          <%= if Enum.any?(@notifications, &(!&1.is_read)) do %>
            <button
              phx-click="mark_all_read"
              class="btn btn-ghost btn-sm gap-2"
              id="mark-all-read-btn"
            >
              <.icon name="hero-check-mini" class="size-4" /> Mark all as read
            </button>
          <% end %>
        </div>

        <%= if @notifications == [] do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-notifications">
            <div class="card-body items-center text-center p-8">
              <div class="w-16 h-16 rounded-2xl bg-base-300/30 flex items-center justify-center mb-4">
                <.icon name="hero-bell-slash" class="size-8 text-base-content/20" />
              </div>
              <h2 class="text-lg font-bold">No Notifications</h2>
              <p class="text-sm text-base-content/50 max-w-md mt-2">
                You're all caught up! We'll notify you about subscription updates and gym activity.
              </p>
            </div>
          </div>
        <% else %>
          <div class="space-y-3" id="notifications-list">
            <div
              :for={notification <- @notifications}
              id={"notification-#{notification.id}"}
              class={"card border transition-all #{if notification.is_read, do: "bg-base-200/30 border-base-300/30", else: "bg-base-200/70 border-primary/20 shadow-sm"}"}
            >
              <div class="card-body p-4 flex-row items-start gap-3">
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
                      <button
                        phx-click="mark_read"
                        phx-value-id={notification.id}
                        class="btn btn-ghost btn-xs shrink-0"
                        title="Mark as read"
                      >
                        <.icon name="hero-check-mini" class="size-4" />
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
