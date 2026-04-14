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
        upcoming_bookings: [],
        streak_count: 0,
        today_calories: 0,
        calorie_target: nil,
        workout_streak: 0,
        attendance_streak: 0,
        milestones: [],
        gym_tier: :free
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

      # Get workout streak
      workout_log_dates = case FitTrackerz.Training.list_workout_log_dates(member_ids, actor: actor) do
        {:ok, logs} -> logs
        _ -> []
      end

      streak_count = calculate_streak(workout_log_dates)

      # Get today's calories
      today = Date.utc_today()
      today_food = case FitTrackerz.Health.list_food_logs_by_date(member_ids, today, actor: actor) do
        {:ok, entries} -> entries
        _ -> []
      end

      today_calories = Enum.reduce(today_food, 0, &(&1.calories + &2))

      calorie_target = case diet_plan do
        nil -> nil
        plan -> plan.calorie_target
      end

      membership = List.first(memberships)

      # Load streaks
      streaks =
        case FitTrackerz.Gamification.list_streaks_by_member(membership.id, actor: actor) do
          {:ok, s} -> s
          _ -> []
        end

      workout_streak_val =
        case Enum.find(streaks, &(&1.streak_type == :workout)) do
          %{current_streak: s} -> s
          _ -> 0
        end

      attendance_streak_val =
        case Enum.find(streaks, &(&1.streak_type == :attendance)) do
          %{current_streak: s} -> s
          _ -> 0
        end

      milestones =
        case FitTrackerz.Gamification.list_milestones_by_member(membership.id, actor: actor) do
          {:ok, m} -> m
          _ -> []
        end

      gym_tier = membership.gym.tier

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
        upcoming_bookings: Enum.take(bookings, 5),
        streak_count: streak_count,
        today_calories: today_calories,
        calorie_target: calorie_target,
        workout_streak: workout_streak_val,
        attendance_streak: attendance_streak_val,
        milestones: milestones,
        gym_tier: gym_tier
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

  defp calculate_streak(logs) do
    dates = logs
      |> Enum.map(& &1.completed_on)
      |> Enum.uniq()
      |> Enum.sort(Date)
      |> Enum.reverse()

    count_streak(dates, Date.utc_today(), 0)
  end

  defp count_streak([], _expected, count), do: count
  defp count_streak([date | rest], expected, count) do
    diff = Date.diff(expected, date)
    cond do
      diff == 0 -> count_streak(rest, Date.add(expected, -1), count + 1)
      diff == 1 -> count_streak([date | rest], Date.add(expected, -1), count)
      true -> count
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Welcome Header --%>
        <.card>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-6">
            <div>
              <p class="text-sm text-base-content/50 font-medium">Good to see you</p>
              <h1 class="text-2xl sm:text-3xl font-brand mt-1">{@current_user.name}</h1>
              <p class="text-base-content/50 mt-1">Keep pushing towards your fitness goals!</p>
            </div>
            <div class="flex gap-2 flex-wrap">
              <.button variant="primary" size="sm" icon="hero-calendar-days" navigate="/member/classes">
                Book a Class
              </.button>
              <.button variant="ghost" size="sm" icon="hero-chart-bar" navigate="/member/health">
                Health Log
              </.button>
              <.button variant="ghost" size="sm" icon="hero-arrow-trending-up" navigate="/member/progress">
                Progress
              </.button>
              <.button variant="ghost" size="sm" icon="hero-qr-code" navigate="/member/qr-code">
                My QR Code
              </.button>
              <%= if @gym_tier == :premium do %>
                <.button variant="ghost" size="sm" icon="hero-trophy" navigate="/member/leaderboard">
                  Leaderboard
                </.button>
              <% end %>
            </div>
          </div>
        </.card>

        <%!-- Pending Invitations --%>
        <%= if @pending_invitations != [] do %>
          <.card title="Pending Invitations">
            <:header_actions>
              <.badge variant="primary">{length(@pending_invitations)}</.badge>
            </:header_actions>
            <div class="space-y-3" id="pending-invitations">
              <%= for inv <- @pending_invitations do %>
                <div
                  class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-base-200/50 border border-base-300/30"
                  id={"invitation-#{inv.id}"}
                >
                  <div class="flex items-center gap-4">
                    <.avatar name={inv.gym.name} size="md" />
                    <div>
                      <p class="font-semibold">{inv.gym.name}</p>
                      <%= if inv.branch do %>
                        <p class="text-sm text-base-content/60">
                          <.icon name="hero-map-pin-mini" class="size-3 inline" />
                          {inv.branch.city}, {inv.branch.state} -- {inv.branch.address}
                        </p>
                      <% end %>
                      <p class="text-sm text-base-content/50">
                        Invited by {inv.invited_by.name} &bull; {Calendar.strftime(inv.inserted_at, "%b %d, %Y")}
                      </p>
                    </div>
                  </div>
                  <div class="flex gap-2 sm:shrink-0">
                    <.button variant="primary" size="sm" icon="hero-check" phx-click="accept-invitation" phx-value-id={inv.id}>
                      Accept
                    </.button>
                    <.button variant="ghost" size="sm" icon="hero-x-mark" phx-click="reject-invitation" phx-value-id={inv.id}>
                      Decline
                    </.button>
                  </div>
                </div>
              <% end %>
            </div>
          </.card>
        <% end %>

        <%= if @no_gym do %>
          <%= if @pending_invitations == [] do %>
            <.empty_state
              icon="hero-building-office-2"
              title="No Gym Membership"
              subtitle="You haven't joined any gym yet. Ask a gym operator to invite you as a member."
            />
          <% end %>
        <% else %>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 sm:gap-6">
            <.stat_card label="Workout Streak" value={"#{@workout_streak} days"} icon="hero-fire" color="warning" />
            <.stat_card label="Attendance Streak" value={"#{@attendance_streak} days"} icon="hero-calendar-days" color="accent" />
            <.stat_card
              label="Active Bookings"
              value={@booking_count}
              icon="hero-ticket"
              color="info"
            />
            <.stat_card
              label="Today's Calories"
              value={@today_calories}
              icon="hero-heart"
              color="warning"
              change={if @calorie_target, do: "/ #{@calorie_target} target", else: nil}
            />
          </div>

          <%!-- Streak Milestones --%>
          <%= if @milestones != [] do %>
            <div class="flex flex-wrap gap-2">
              <%= for m <- @milestones do %>
                <.badge variant="warning" size="sm">
                  <.icon name="hero-star-solid" class="size-3 mr-1" />
                  {m.milestone_days}-day {m.streak_type} streak
                </.badge>
              <% end %>
            </div>
          <% end %>

          <%!-- Main Content Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <%!-- My Workout Plan --%>
            <.card title="My Workout Plan" id="my-workout">
              <:header_actions>
                <.button variant="ghost" size="sm" icon="hero-arrow-right" navigate="/member/workout">
                  View Full Plan
                </.button>
              </:header_actions>
              <%= if @workout_plan do %>
                <div class="space-y-2">
                  <p class="font-semibold text-lg">{@workout_plan.name}</p>
                  <p class="text-sm text-base-content/50">
                    {length(@workout_plan.exercises || [])} exercises
                  </p>
                </div>
              <% else %>
                <.empty_state
                  icon="hero-fire"
                  title="No Workout Plan Yet"
                  subtitle="Your gym operator will assign a workout plan tailored for you."
                />
              <% end %>
            </.card>

            <%!-- My Diet Plan --%>
            <.card title="My Diet Plan" id="my-diet">
              <:header_actions>
                <.button variant="ghost" size="sm" icon="hero-arrow-right" navigate="/member/diet">
                  View Full Plan
                </.button>
              </:header_actions>
              <%= if @diet_plan do %>
                <div class="space-y-2">
                  <p class="font-semibold text-lg">{@diet_plan.name}</p>
                  <%= if @diet_plan.calorie_target do %>
                    <p class="text-sm text-base-content/50">
                      {@diet_plan.calorie_target} kcal/day target
                    </p>
                  <% end %>
                </div>
              <% else %>
                <.empty_state
                  icon="hero-heart"
                  title="No Diet Plan Yet"
                  subtitle="Your gym operator will create a nutrition plan based on your goals."
                />
              <% end %>
            </.card>
          </div>

          <%!-- Upcoming Bookings & Subscription --%>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Upcoming Bookings --%>
            <div class="lg:col-span-2">
              <.card title="Upcoming Bookings" id="upcoming-bookings">
                <:header_actions>
                  <.button variant="ghost" size="sm" icon="hero-arrow-right" navigate="/member/classes">
                    Browse Classes
                  </.button>
                </:header_actions>
                <%= if @upcoming_bookings == [] do %>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50">
                    <.icon name="hero-calendar" class="size-5 text-base-content/30" />
                    <p class="text-sm text-base-content/50">
                      No upcoming bookings.
                      <.link navigate="/member/classes" class="text-primary hover:underline">
                        Browse available classes
                      </.link>
                    </p>
                  </div>
                <% else %>
                  <div class="space-y-2">
                    <%= for booking <- @upcoming_bookings do %>
                      <div class="flex items-center justify-between p-3 rounded-lg bg-base-200/50">
                        <div class="flex items-center gap-3">
                          <div class="w-8 h-8 rounded-lg bg-info/10 flex items-center justify-center shrink-0">
                            <.icon name="hero-calendar-days-solid" class="size-4 text-info" />
                          </div>
                          <span class="font-medium text-sm">
                            {booking.scheduled_class.class_definition.name}
                          </span>
                        </div>
                        <span class="text-sm text-base-content/60">
                          {Calendar.strftime(booking.scheduled_class.scheduled_at, "%b %d, %H:%M")}
                        </span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </.card>
            </div>

            <%!-- Subscription Status --%>
            <.card title="Subscription" id="subscription-status">
              <%= if @subscription do %>
                <div class="space-y-4">
                  <.badge variant="success">Active</.badge>
                  <p class="font-semibold text-lg">{@subscription.subscription_plan.name}</p>
                  <p class="text-sm text-base-content/50">
                    Expires: {Calendar.strftime(@subscription.ends_at, "%b %d, %Y")}
                  </p>
                </div>
              <% else %>
                <.empty_state
                  icon="hero-credit-card"
                  title="No Active Subscription"
                  subtitle="Contact your gym to subscribe to a plan."
                />
              <% end %>
            </.card>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
