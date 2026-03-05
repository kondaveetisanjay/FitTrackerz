defmodule FitconnexWeb.Member.DashboardLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok, load_dashboard(socket, user)}
  end

  defp load_dashboard(socket, user) do
    actor = user

    pending_invitations = case Fitconnex.Gym.list_pending_member_invitations(actor.email, actor: actor, load: [:gym, :invited_by, :branch]) do
      {:ok, invitations} -> invitations
      _ -> []
    end

    memberships = case Fitconnex.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
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
      workout_plan = case Fitconnex.Training.list_workouts_by_member(member_ids, actor: actor) do
        {:ok, plans} -> List.first(plans)
        _ -> nil
      end

      # Get latest diet plan
      diet_plan = case Fitconnex.Training.list_diets_by_member(member_ids, actor: actor) do
        {:ok, plans} -> List.first(plans)
        _ -> nil
      end

      # Get bookings
      bookings = case Fitconnex.Scheduling.list_bookings_by_member(member_ids, actor: actor, load: [scheduled_class: [:class_definition, :branch]]) do
        {:ok, bookings} -> Enum.filter(bookings, &(&1.status == :confirmed))
        _ -> []
      end

      # Get attendance count
      attendance_records = case Fitconnex.Training.list_attendance_by_member(member_ids, actor: actor) do
        {:ok, records} -> records
        _ -> []
      end

      now = DateTime.utc_now()

      this_month_attendance =
        Enum.count(attendance_records, fn r ->
          r.attended_at.month == now.month and r.attended_at.year == now.year
        end)

      # Get active subscription
      subscription = case Fitconnex.Billing.list_active_subscriptions_by_member(member_ids, actor: actor, load: [:subscription_plan, :gym]) do
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

    case Fitconnex.Gym.get_member_invitation(id, actor: actor, load: [:gym]) do
      {:ok, invitation} ->
        case Fitconnex.Gym.accept_member_invitation(invitation, %{}, actor: actor) do
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

    case Fitconnex.Gym.get_member_invitation(id, actor: actor) do
      {:ok, invitation} ->
        case Fitconnex.Gym.reject_member_invitation(invitation, %{}, actor: actor) do
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
      <div class="space-y-8">
        <%!-- Welcome Header --%>
        <div class="card bg-gradient-to-r from-primary/10 via-base-200/50 to-secondary/10 border border-base-300/50">
          <div class="card-body p-6">
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div>
                <p class="text-sm text-base-content/50 font-medium">Good to see you</p>

                <h1 class="text-2xl sm:text-3xl font-brand mt-1">
                  {@current_user.name}
                </h1>

                <p class="text-base-content/50 mt-1">Keep pushing towards your fitness goals!</p>
              </div>

              <div class="flex gap-2">
                <.link navigate="/member/classes" class="btn btn-primary btn-sm gap-2 font-semibold">
                  <.icon name="hero-calendar-days-mini" class="size-4" /> Book a Class
                </.link>
              </div>
            </div>
          </div>
        </div>

        <%!-- Pending Invitations --%>
        <%= if @pending_invitations != [] do %>
          <div class="card bg-base-200/50 border border-primary/30" id="pending-invitations">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-envelope-solid" class="size-5 text-primary" />
                Pending Invitations
                <span class="badge badge-primary badge-sm">{length(@pending_invitations)}</span>
              </h2>

              <div class="space-y-3 mt-4">
                <%= for inv <- @pending_invitations do %>
                  <div
                    class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-base-300/30 border border-base-300/50"
                    id={"invitation-#{inv.id}"}
                  >
                    <div class="flex items-center gap-4">
                      <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                        <.icon name="hero-building-office-2-solid" class="size-5 text-primary" />
                      </div>

                      <div>
                        <p class="font-semibold">{inv.gym.name}</p>

                        <%= if inv.branch do %>
                          <p class="text-sm text-base-content/60">
                            <.icon name="hero-map-pin-mini" class="size-3 inline" />
                            {inv.branch.city}, {inv.branch.state} — {inv.branch.address}
                          </p>
                        <% end %>

                        <p class="text-sm text-base-content/50">
                          Invited by {inv.invited_by.name} &bull; {Calendar.strftime(inv.inserted_at, "%b %d, %Y")}
                        </p>
                      </div>
                    </div>

                    <div class="flex gap-2 sm:shrink-0">
                      <button
                        phx-click="accept-invitation"
                        phx-value-id={inv.id}
                        class="btn btn-success btn-sm gap-1 font-semibold"
                      >
                        <.icon name="hero-check-mini" class="size-4" /> Accept
                      </button>

                      <button
                        phx-click="reject-invitation"
                        phx-value-id={inv.id}
                        class="btn btn-ghost btn-sm gap-1"
                      >
                        <.icon name="hero-x-mark-mini" class="size-4" /> Decline
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @no_gym do %>
          <%= if @pending_invitations == [] do %>
            <div class="min-h-[40vh] flex items-center justify-center">
              <div class="text-center max-w-md">
                <div class="w-20 h-20 rounded-3xl bg-warning/10 flex items-center justify-center mx-auto mb-6">
                  <.icon name="hero-building-office-2-solid" class="size-10 text-warning" />
                </div>

                <h2 class="text-xl font-brand">No Gym Membership</h2>

                <p class="text-base-content/50 mt-3">
                  You haven't joined any gym yet. Ask a gym operator to invite you as a member.
                </p>
              </div>
            </div>
          <% end %>
        <% else %>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <.link
              navigate="/member/bookings"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-bookings"
            >
              <div class="card-body p-4 sm:p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Bookings
                    </p>

                    <p class="text-2xl sm:text-3xl font-black mt-1">{@booking_count}</p>
                  </div>

                  <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-ticket-solid" class="size-5 sm:size-6 text-info" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Active bookings</p>
              </div>
            </.link>
            <.link
              navigate="/member/attendance"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-attendance"
            >
              <div class="card-body p-4 sm:p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Attendance
                    </p>

                    <p class="text-2xl sm:text-3xl font-black mt-1">{@attendance_count}</p>
                  </div>

                  <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-success/10 flex items-center justify-center">
                    <.icon name="hero-check-badge-solid" class="size-5 sm:size-6 text-success" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">This month</p>
              </div>
            </.link>
            <.link
              navigate="/member/workout"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-workout"
            >
              <div class="card-body p-4 sm:p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Workout
                    </p>

                    <p class="text-2xl sm:text-3xl font-black mt-1">
                      {if @workout_plan, do: length(@workout_plan.exercises || []), else: "--"}
                    </p>
                  </div>

                  <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-accent/10 flex items-center justify-center">
                    <.icon name="hero-fire-solid" class="size-5 sm:size-6 text-accent" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Exercises</p>
              </div>
            </.link>
            <.link
              navigate="/member/diet"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-calories"
            >
              <div class="card-body p-4 sm:p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Calories
                    </p>

                    <p class="text-2xl sm:text-3xl font-black mt-1">
                      {if @diet_plan && @diet_plan.calorie_target,
                        do: @diet_plan.calorie_target,
                        else: "--"}
                    </p>
                  </div>

                  <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-warning/10 flex items-center justify-center">
                    <.icon name="hero-heart-solid" class="size-5 sm:size-6 text-warning" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Daily target</p>
              </div>
            </.link>
          </div>
          <%!-- Main Content Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <%!-- My Workout Plan --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="my-workout">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <.icon name="hero-fire-solid" class="size-5 text-accent" /> My Workout Plan
                  </h2>

                  <.link navigate="/member/workout" class="btn btn-ghost btn-xs gap-1">
                    View Full Plan <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @workout_plan do %>
                    <div class="space-y-2">
                      <p class="font-semibold">{@workout_plan.name}</p>

                      <p class="text-sm text-base-content/50">
                        {length(@workout_plan.exercises || [])} exercises
                      </p>
                    </div>
                  <% else %>
                    <div class="p-4 rounded-xl bg-base-300/30 text-center">
                      <div class="w-14 h-14 rounded-2xl bg-accent/10 flex items-center justify-center mx-auto mb-3">
                        <.icon name="hero-fire" class="size-7 text-accent" />
                      </div>

                      <p class="text-sm font-semibold">No Workout Plan Yet</p>

                      <p class="text-xs text-base-content/40 mt-1">
                        Your gym operator will assign a workout plan tailored for you.
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            <%!-- My Diet Plan --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="my-diet">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <.icon name="hero-heart-solid" class="size-5 text-success" /> My Diet Plan
                  </h2>

                  <.link navigate="/member/diet" class="btn btn-ghost btn-xs gap-1">
                    View Full Plan <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @diet_plan do %>
                    <div class="space-y-2">
                      <p class="font-semibold">{@diet_plan.name}</p>

                      <%= if @diet_plan.calorie_target do %>
                        <p class="text-sm text-base-content/50">
                          {@diet_plan.calorie_target} kcal/day target
                        </p>
                      <% end %>
                    </div>
                  <% else %>
                    <div class="p-4 rounded-xl bg-base-300/30 text-center">
                      <div class="w-14 h-14 rounded-2xl bg-success/10 flex items-center justify-center mx-auto mb-3">
                        <.icon name="hero-heart" class="size-7 text-success" />
                      </div>

                      <p class="text-sm font-semibold">No Diet Plan Yet</p>

                      <p class="text-xs text-base-content/40 mt-1">
                        Your gym operator will create a nutrition plan based on your goals.
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          <%!-- Upcoming Bookings & Subscription --%>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Upcoming Bookings --%>
            <div
              class="lg:col-span-2 card bg-base-200/50 border border-base-300/50"
              id="upcoming-bookings"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <.icon name="hero-calendar-days-solid" class="size-5 text-info" />
                    Upcoming Bookings
                  </h2>

                  <.link navigate="/member/classes" class="btn btn-ghost btn-xs gap-1">
                    Browse Classes <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @upcoming_bookings == [] do %>
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                      <.icon name="hero-calendar" class="size-5 text-base-content/30" />
                      <p class="text-sm text-base-content/50">
                        No upcoming bookings.
                        <.link navigate="/member/classes" class="text-primary hover:underline">
                          Browse available classes
                        </.link>
                      </p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="table table-sm">
                        <thead>
                          <tr class="text-base-content/40">
                            <th>Class</th>

                            <th>Date & Time</th>
                          </tr>
                        </thead>

                        <tbody>
                          <%= for booking <- @upcoming_bookings do %>
                            <tr>
                              <td class="font-medium">
                                {booking.scheduled_class.class_definition.name}
                              </td>

                              <td class="text-base-content/60">
                                {Calendar.strftime(
                                  booking.scheduled_class.scheduled_at,
                                  "%b %d, %H:%M"
                                )}
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            <%!-- Subscription Status --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="subscription-status">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-credit-card-solid" class="size-5 text-warning" /> Subscription
                </h2>

                <div class="mt-4">
                  <%= if @subscription do %>
                    <div class="space-y-3">
                      <div class="p-3 rounded-lg bg-success/10 border border-success/20">
                        <div class="flex items-center gap-2">
                          <.icon name="hero-check-circle-solid" class="size-4 text-success" />
                          <span class="text-sm font-semibold text-success">Active</span>
                        </div>
                      </div>

                      <p class="font-semibold">{@subscription.subscription_plan.name}</p>

                      <p class="text-xs text-base-content/50">
                        Expires: {Calendar.strftime(@subscription.ends_at, "%b %d, %Y")}
                      </p>
                    </div>
                  <% else %>
                    <div class="p-4 rounded-xl bg-base-300/30 text-center">
                      <div class="w-14 h-14 rounded-2xl bg-warning/10 flex items-center justify-center mx-auto mb-3">
                        <.icon name="hero-credit-card" class="size-7 text-warning" />
                      </div>

                      <p class="text-sm font-semibold">No Active Subscription</p>

                      <p class="text-xs text-base-content/40 mt-1">
                        Contact your gym to subscribe to a plan.
                      </p>
                    </div>
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
end
