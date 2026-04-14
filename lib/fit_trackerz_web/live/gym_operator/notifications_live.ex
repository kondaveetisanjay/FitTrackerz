defmodule FitTrackerzWeb.GymOperator.NotificationsLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "notifications:#{actor.id}")

      # Also subscribe to gym-level notifications
      case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
        {:ok, [gym | _]} ->
          Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "gym_notifications:#{gym.id}")

        _ ->
          :ok
      end
    end

    notifications = load_notifications(actor)
    expiring_members = load_expiring_members(actor)

    {:ok,
     assign(socket,
       page_title: "Notifications",
       notifications: notifications,
       expiring_members: expiring_members
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

    Enum.filter(socket.assigns.notifications, &(!&1.is_read))
    |> Enum.each(fn n ->
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

  def handle_info({:member_subscription_expiring, _payload}, socket) do
    expiring_members = load_expiring_members(socket.assigns.current_user)
    {:noreply, assign(socket, expiring_members: expiring_members)}
  end

  defp load_notifications(actor) do
    case FitTrackerz.Notifications.list_notifications(actor.id, actor: actor) do
      {:ok, notifications} -> notifications
      _ -> []
    end
  end

  defp load_expiring_members(actor) do
    import Ecto.Query

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        today = DateTime.utc_now()
        three_days = DateTime.add(today, 3, :day)

        FitTrackerz.Billing.MemberSubscription
        |> where([s], s.gym_id == ^gym.id and s.status == :active and s.ends_at <= ^three_days and s.ends_at >= ^today)
        |> join(:left, [s], m in assoc(s, :member))
        |> join(:left, [s, m], u in assoc(m, :user))
        |> join(:left, [s], p in assoc(s, :subscription_plan))
        |> select([s, m, u, p], %{
          subscription_id: s.id,
          member_name: u.name,
          member_email: u.email,
          plan_name: p.name,
          ends_at: s.ends_at,
          payment_status: s.payment_status
        })
        |> FitTrackerz.Repo.all()

      _ ->
        []
    end
  end

  defp notification_icon(:subscription_expiring), do: "hero-clock-solid"
  defp notification_icon(:subscription_expired), do: "hero-exclamation-triangle-solid"
  defp notification_icon(:payment_due), do: "hero-currency-rupee-solid"
  defp notification_icon(:payment_received), do: "hero-check-circle-solid"
  defp notification_icon(_), do: "hero-bell-solid"

  defp notification_color(:subscription_expiring), do: "text-warning"
  defp notification_color(:subscription_expired), do: "text-error"
  defp notification_color(:payment_due), do: "text-warning"
  defp notification_color(:payment_received), do: "text-success"
  defp notification_color(_), do: "text-base-content/50"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp days_until(ends_at) do
    now = DateTime.utc_now()
    diff = DateTime.diff(ends_at, now, :day)
    if diff < 0, do: 0, else: diff
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <.page_header title="Notifications" subtitle="Subscription alerts and gym updates." back_path="/gym">
          <:actions>
            <%= if Enum.any?(@notifications, &(!&1.is_read)) do %>
              <.button variant="ghost" size="sm" icon="hero-check" phx-click="mark_all_read" id="mark-all-read-btn">
                Mark all as read
              </.button>
            <% end %>
          </:actions>
        </.page_header>

        <%!-- Expiring Members Alert --%>
        <%= if @expiring_members != [] do %>
          <.alert variant="warning" id="expiring-members-card">
            <div>
              <h2 class="text-lg font-bold flex items-center gap-2 text-warning">
                <.icon name="hero-exclamation-triangle-solid" class="size-5" />
                Members Expiring Soon
                <.badge variant="warning" size="sm">{length(@expiring_members)}</.badge>
              </h2>
              <div class="overflow-x-auto mt-3">
                <table class="table table-sm">
                  <thead>
                    <tr class="text-base-content/40">
                      <th>Member</th>
                      <th>Plan</th>
                      <th>Expires</th>
                      <th>Days Left</th>
                      <th>Payment</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for member <- @expiring_members do %>
                      <tr>
                        <td>
                          <div class="flex items-center gap-2">
                            <.avatar name={member.member_name} size="sm" />
                            <div>
                              <span class="font-medium">{member.member_name}</span>
                              <p class="text-xs text-base-content/50">{member.member_email}</p>
                            </div>
                          </div>
                        </td>
                        <td>{member.plan_name}</td>
                        <td>{format_date(member.ends_at)}</td>
                        <td>
                          <% days = days_until(member.ends_at) %>
                          <.badge variant={if days <= 1, do: "error", else: if(days <= 3, do: "warning", else: "info")} size="sm">
                            {days} day{if days != 1, do: "s"}
                          </.badge>
                        </td>
                        <td>
                          <.badge variant={if member.payment_status == :paid, do: "success", else: "warning"} size="sm">
                            {member.payment_status |> to_string() |> String.capitalize()}
                          </.badge>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <div class="mt-3">
                <.button variant="outline" size="sm" icon="hero-user-group" navigate="/gym/members">
                  Manage Members
                </.button>
              </div>
            </div>
          </.alert>
        <% end %>

        <%!-- All Notifications --%>
        <%= if @notifications == [] do %>
          <.empty_state
            icon="hero-bell-slash"
            title="No Notifications"
            subtitle="You're all caught up! We'll notify you about member subscription updates."
          />
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
                      <.button variant="ghost" size="sm" phx-click="mark_read" phx-value-id={notification.id} icon="hero-check">
                        <span class="sr-only">Mark as read</span>
                      </.button>
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
