defmodule FitTrackerzWeb.Member.DashboardLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok, load_dashboard(socket, user)}
  end

  defp load_dashboard(socket, user) do
    actor = user

    pending_invitations = case FitTrackerz.Gym.list_pending_member_invitations(actor.email, actor: actor, load: [:gym, :invited_by, :branch]) do
      {:ok, invitations} -> invitations
      _ -> []
    end

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    if memberships == [] do
      socket
      |> assign(
        page_title: "Member Dashboard",
        no_gym: true,
        pending_invitations: pending_invitations,
        booking_count: 0,
        attendance_count: 0,
        workout_plan: nil,
        diet_plan: nil,
        subscription: nil,
        upcoming_bookings: []
      )
    else
      member_ids = Enum.map(memberships, & &1.id)

      # Get latest workout plan
      workout_plan = case FitTrackerz.Training.list_workouts_by_member(member_ids, actor: actor) do
        {:ok, plans} -> List.first(plans)
        _ -> nil
      end

      # Get latest diet plan
      diet_plan = case FitTrackerz.Training.list_diets_by_member(member_ids, actor: actor) do
        {:ok, plans} -> List.first(plans)
        _ -> nil
      end

      # Get bookings
      bookings = case FitTrackerz.Scheduling.list_bookings_by_member(member_ids, actor: actor, load: [scheduled_class: [:class_definition, :branch]]) do
        {:ok, bookings} -> Enum.filter(bookings, &(&1.status == :confirmed))
        _ -> []
      end

      # Get attendance count
      attendance_records = case FitTrackerz.Training.list_attendance_by_member(member_ids, actor: actor) do
        {:ok, records} -> records
        _ -> []
      end

      now = DateTime.utc_now()

      this_month_attendance =
        Enum.count(attendance_records, fn r ->
          r.attended_at.month == now.month and r.attended_at.year == now.year
        end)

      # Get active subscription
      subscription = case FitTrackerz.Billing.list_active_subscriptions_by_member(member_ids, actor: actor, load: [:subscription_plan, :gym]) do
        {:ok, subs} -> List.first(subs)
        _ -> nil
      end

      socket
      |> assign(
        page_title: "Member Dashboard",
        no_gym: false,
        pending_invitations: pending_invitations,
        booking_count: length(bookings),
        attendance_count: this_month_attendance,
        workout_plan: workout_plan,
        diet_plan: diet_plan,
        subscription: subscription,
        upcoming_bookings: Enum.take(bookings, 5)
      )
    end
  end

  @impl true
  def handle_event("accept-invitation", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_member_invitation(id, actor: actor, load: [:gym]) do
      {:ok, invitation} ->
        case FitTrackerz.Gym.accept_member_invitation(invitation, %{}, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Invitation accepted! You've joined #{invitation.gym.name}.")
             |> load_dashboard(actor)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to accept invitation. Please try again.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invitation not found.")}
    end
  end

  @impl true
  def handle_event("reject-invitation", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_member_invitation(id, actor: actor) do
      {:ok, invitation} ->
        case FitTrackerz.Gym.reject_member_invitation(invitation, %{}, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Invitation declined.")
             |> load_dashboard(actor)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to decline invitation. Please try again.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invitation not found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%!-- Welcome Header --%>
        <div class="relative rounded-2xl overflow-hidden gradient-mesh bg-base-200/50 border border-base-300/30">
          <div class="absolute inset-0 overflow-hidden pointer-events-none">
            <div class="absolute top-0 right-0 w-40 h-40 rounded-full bg-primary/5 blur-2xl -translate-y-1/2 translate-x-1/2"></div>
            <div class="absolute bottom-0 left-0 w-32 h-32 rounded-full bg-secondary/5 blur-2xl translate-y-1/2 -translate-x-1/2"></div>
          </div>
          <div class="relative p-6 sm:p-8">
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div>
                <p class="text-sm text-base-content/40 font-medium tracking-wide">
                  {greeting()}, welcome back
                </p>
                <h1 class="text-2xl sm:text-3xl font-brand mt-1">
                  {@current_user.name}
                </h1>
                <p class="text-base-content/50 mt-1.5 text-sm">
                  Keep pushing towards your fitness goals — every rep counts!
                </p>
              </div>
              <div class="flex gap-2 sm:shrink-0">
                <.link navigate="/member/classes" class="btn btn-primary btn-sm gap-2 font-semibold shadow-md shadow-primary/20">
                  <.icon name="hero-calendar-days-mini" class="size-4" /> Book a Class
                </.link>
                <.link navigate="/explore" class="btn btn-ghost btn-sm gap-2 font-semibold">
                  <.icon name="hero-magnifying-glass-mini" class="size-4" /> Explore
                </.link>
              </div>
            </div>
          </div>
        </div>

        <%!-- Pending Invitations --%>
        <%= if @pending_invitations != [] do %>
          <div class="premium-card" id="pending-invitations">
            <div class="p-5">
              <.section_header icon="hero-envelope-solid" icon_color="primary" title="Pending Invitations">
                <:actions>
                  <span class="badge badge-primary badge-sm">{length(@pending_invitations)}</span>
                </:actions>
              </.section_header>
              <div class="space-y-3 mt-4">
                <%= for inv <- @pending_invitations do %>
                  <div
                    class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-base-300/20 border border-primary/10 hover:border-primary/20 transition-colors"
                    id={"invitation-#{inv.id}"}
                  >
                    <div class="flex items-center gap-4">
                      <div class="w-11 h-11 rounded-xl bg-gradient-to-br from-primary/15 to-primary/5 flex items-center justify-center shrink-0">
                        <.icon name="hero-building-office-2-solid" class="size-5 text-primary" />
                      </div>
                      <div>
                        <p class="font-bold">{inv.gym.name}</p>
                        <%= if inv.branch do %>
                          <p class="text-sm text-base-content/50 flex items-center gap-1 mt-0.5">
                            <.icon name="hero-map-pin-mini" class="size-3" />
                            {inv.branch.city}, {inv.branch.state}
                          </p>
                        <% end %>
                        <p class="text-xs text-base-content/35 mt-0.5">
                          Invited by {inv.invited_by.name} · {Calendar.strftime(inv.inserted_at, "%b %d, %Y")}
                        </p>
                      </div>
                    </div>
                    <div class="flex gap-2 sm:shrink-0">
                      <.button phx-click="accept-invitation" phx-value-id={inv.id} class="btn btn-success btn-sm gap-1.5 font-semibold shadow-sm">
                        <.icon name="hero-check-mini" class="size-4" /> Accept
                      </.button>
                      <.button phx-click="reject-invitation" phx-value-id={inv.id} class="btn btn-ghost btn-sm gap-1">
                        <.icon name="hero-x-mark-mini" class="size-4" /> Decline
                      </.button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @no_gym do %>
          <%= if @pending_invitations == [] do %>
            <.empty_state
              icon="hero-building-office-2-solid"
              color="warning"
              title="No Gym Membership Yet"
              message="You haven't joined any gym yet. Ask a gym operator to invite you as a member, or explore gyms near you."
            >
              <:actions>
                <.link navigate="/explore" class="btn btn-primary btn-sm gap-2 shadow-md shadow-primary/20">
                  <.icon name="hero-magnifying-glass-mini" class="size-4" /> Explore Nearby Gyms
                </.link>
              </:actions>
            </.empty_state>
          <% end %>
        <% else %>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <.stat_card
              label="Bookings"
              value={@booking_count}
              icon="hero-ticket-solid"
              color="info"
              subtitle="Active bookings"
              href="/member/bookings"
              id="stat-bookings"
            />
            <.stat_card
              label="Attendance"
              value={@attendance_count}
              icon="hero-check-badge-solid"
              color="success"
              subtitle="This month"
              href="/member/attendance"
              id="stat-attendance"
            />
            <.stat_card
              label="Workout"
              value={if @workout_plan, do: length(@workout_plan.exercises || []), else: "--"}
              icon="hero-fire-solid"
              color="accent"
              subtitle="Exercises"
              href="/member/workout"
              id="stat-workout"
            />
            <.stat_card
              label="Calories"
              value={if @diet_plan && @diet_plan.calorie_target, do: @diet_plan.calorie_target, else: "--"}
              icon="hero-heart-solid"
              color="warning"
              subtitle="Daily target"
              href="/member/diet"
              id="stat-calories"
            />
          </div>

          <%!-- Main Content Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <%!-- My Workout Plan --%>
            <div class="premium-card" id="my-workout">
              <div class="p-5">
                <.section_header icon="hero-fire-solid" icon_color="accent" title="My Workout Plan">
                  <:actions>
                    <.link navigate="/member/workout" class="btn btn-ghost btn-xs gap-1 font-semibold">
                      View Plan <.icon name="hero-arrow-right-mini" class="size-3" />
                    </.link>
                  </:actions>
                </.section_header>
                <div class="mt-4">
                  <%= if @workout_plan do %>
                    <div class="p-4 rounded-xl bg-base-300/20 hover:bg-base-300/30 transition-colors">
                      <div class="flex items-center justify-between">
                        <div>
                          <p class="font-bold">{@workout_plan.name}</p>
                          <p class="text-sm text-base-content/50 mt-1 flex items-center gap-1.5">
                            <.icon name="hero-list-bullet-mini" class="size-3.5" />
                            {length(@workout_plan.exercises || [])} exercises
                          </p>
                        </div>
                        <div class="w-10 h-10 rounded-xl bg-accent/10 flex items-center justify-center">
                          <.icon name="hero-fire-solid" class="size-5 text-accent" />
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <.empty_state
                      icon="hero-fire"
                      color="accent"
                      title="No Workout Plan Yet"
                      message="Your gym operator will assign a workout plan tailored for you."
                    />
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- My Diet Plan --%>
            <div class="premium-card" id="my-diet">
              <div class="p-5">
                <.section_header icon="hero-heart-solid" icon_color="success" title="My Diet Plan">
                  <:actions>
                    <.link navigate="/member/diet" class="btn btn-ghost btn-xs gap-1 font-semibold">
                      View Plan <.icon name="hero-arrow-right-mini" class="size-3" />
                    </.link>
                  </:actions>
                </.section_header>
                <div class="mt-4">
                  <%= if @diet_plan do %>
                    <div class="p-4 rounded-xl bg-base-300/20 hover:bg-base-300/30 transition-colors">
                      <div class="flex items-center justify-between">
                        <div>
                          <p class="font-bold">{@diet_plan.name}</p>
                          <%= if @diet_plan.calorie_target do %>
                            <p class="text-sm text-base-content/50 mt-1 flex items-center gap-1.5">
                              <.icon name="hero-fire-mini" class="size-3.5" />
                              {@diet_plan.calorie_target} kcal/day target
                            </p>
                          <% end %>
                        </div>
                        <div class="w-10 h-10 rounded-xl bg-success/10 flex items-center justify-center">
                          <.icon name="hero-heart-solid" class="size-5 text-success" />
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <.empty_state
                      icon="hero-heart"
                      color="success"
                      title="No Diet Plan Yet"
                      message="Your gym operator will create a nutrition plan based on your goals."
                    />
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%!-- Upcoming Bookings & Subscription --%>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Upcoming Bookings --%>
            <div class="lg:col-span-2 premium-card" id="upcoming-bookings">
              <div class="p-5">
                <.section_header icon="hero-calendar-days-solid" icon_color="info" title="Upcoming Bookings">
                  <:actions>
                    <.link navigate="/member/classes" class="btn btn-ghost btn-xs gap-1 font-semibold">
                      Browse Classes <.icon name="hero-arrow-right-mini" class="size-3" />
                    </.link>
                  </:actions>
                </.section_header>
                <div class="mt-4">
                  <%= if @upcoming_bookings == [] do %>
                    <div class="flex items-center gap-3 p-4 rounded-xl bg-base-300/20">
                      <div class="w-9 h-9 rounded-lg bg-info/10 flex items-center justify-center shrink-0">
                        <.icon name="hero-calendar" class="size-4 text-info/50" />
                      </div>
                      <p class="text-sm text-base-content/50">
                        No upcoming bookings.
                        <.link navigate="/member/classes" class="text-primary font-semibold hover:underline">
                          Browse available classes →
                        </.link>
                      </p>
                    </div>
                  <% else %>
                    <div class="space-y-2">
                      <%= for booking <- @upcoming_bookings do %>
                        <div class="flex items-center gap-3 p-3 rounded-xl bg-base-300/15 hover:bg-base-300/25 transition-colors">
                          <div class="w-10 h-10 rounded-xl bg-info/10 flex flex-col items-center justify-center shrink-0">
                            <span class="text-[10px] font-bold text-info leading-none">
                              {Calendar.strftime(booking.scheduled_class.scheduled_at, "%b")}
                            </span>
                            <span class="text-sm font-black text-info leading-tight">
                              {Calendar.strftime(booking.scheduled_class.scheduled_at, "%d")}
                            </span>
                          </div>
                          <div class="flex-1 min-w-0">
                            <p class="text-sm font-bold truncate">
                              {booking.scheduled_class.class_definition.name}
                            </p>
                            <p class="text-xs text-base-content/40 mt-0.5">
                              {Calendar.strftime(booking.scheduled_class.scheduled_at, "%H:%M")}
                            </p>
                          </div>
                          <span class="badge badge-info badge-outline badge-xs shrink-0">Confirmed</span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Subscription Status --%>
            <div class="premium-card" id="subscription-status">
              <div class="p-5">
                <.section_header icon="hero-credit-card-solid" icon_color="warning" title="Subscription" />
                <div class="mt-4">
                  <%= if @subscription do %>
                    <div class="space-y-3">
                      <div class="p-3 rounded-xl bg-success/8 border border-success/15">
                        <div class="flex items-center gap-2">
                          <div class="w-2 h-2 rounded-full bg-success animate-pulse"></div>
                          <span class="text-sm font-bold text-success">Active</span>
                        </div>
                      </div>
                      <div>
                        <p class="font-bold">{@subscription.subscription_plan.name}</p>
                        <p class="text-xs text-base-content/40 mt-1 flex items-center gap-1">
                          <.icon name="hero-clock-mini" class="size-3" />
                          Expires: {Calendar.strftime(@subscription.ends_at, "%b %d, %Y")}
                        </p>
                      </div>
                    </div>
                  <% else %>
                    <.empty_state
                      icon="hero-credit-card"
                      color="warning"
                      title="No Active Subscription"
                      message="Contact your gym to subscribe to a plan."
                    />
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp greeting do
    hour = DateTime.utc_now().hour

    cond do
      hour < 12 -> "Good morning"
      hour < 17 -> "Good afternoon"
      true -> "Good evening"
    end
  end
end

