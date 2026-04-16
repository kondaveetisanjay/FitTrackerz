defmodule FitTrackerzWeb.Member.DashboardLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok, load_dashboard(socket, user)}
  end

  defp load_dashboard(socket, user) do
    actor = user

    pending_invitations =
      case FitTrackerz.Gym.list_pending_member_invitations(actor.email,
             actor: actor,
             load: [:gym, :invited_by, :branch]
           ) do
        {:ok, invitations} -> invitations
        _ -> []
      end

    memberships =
      case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
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
      workout_plan =
        case FitTrackerz.Training.list_workouts_by_member(member_ids, actor: actor) do
          {:ok, plans} -> List.first(plans)
          _ -> nil
        end

      # Get latest diet plan
      diet_plan =
        case FitTrackerz.Training.list_diets_by_member(member_ids, actor: actor) do
          {:ok, plans} -> List.first(plans)
          _ -> nil
        end

      # Get bookings
      bookings =
        case FitTrackerz.Scheduling.list_bookings_by_member(member_ids,
               actor: actor,
               load: [scheduled_class: [:class_definition, :branch]]
             ) do
          {:ok, bookings} -> Enum.filter(bookings, &(&1.status == :confirmed))
          _ -> []
        end

      # Get attendance count
      attendance_records =
        case FitTrackerz.Training.list_attendance_by_member(member_ids, actor: actor) do
          {:ok, records} -> records
          _ -> []
        end

      now = DateTime.utc_now()

      this_month_attendance =
        Enum.count(attendance_records, fn r ->
          r.attended_at.month == now.month and r.attended_at.year == now.year
        end)

      # Get active subscription
      subscription =
        case FitTrackerz.Billing.list_active_subscriptions_by_member(member_ids,
               actor: actor,
               load: [:subscription_plan, :gym]
             ) do
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
            {:noreply,
             put_flash(socket, :error, "Failed to accept invitation. Please try again.")}
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
            {:noreply,
             put_flash(socket, :error, "Failed to decline invitation. Please try again.")}
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
        <%!-- Welcome Header (elevated hero with glow) --%>
        <div class="surface-3 accent-top relative overflow-hidden reveal">
          <%!-- Decorative glow blobs --%>
          <div class="pointer-events-none absolute -top-16 -right-16 w-56 h-56 rounded-full bg-primary/25 blur-3xl"></div>
          <div class="pointer-events-none absolute -bottom-20 -left-12 w-48 h-48 rounded-full bg-secondary/20 blur-3xl"></div>

          <div class="relative p-6 sm:p-8">
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-5">
              <div>
                <p class="text-sm text-base-content/50 font-semibold uppercase tracking-wider">Good to see you</p>
                <h1 class="text-3xl sm:text-4xl font-brand mt-2 text-gradient-brand">
                  {@current_user.name}
                </h1>
                <p class="text-base-content/60 mt-2">Keep pushing towards your fitness goals.</p>
              </div>

              <div class="flex gap-2">
                <.link navigate="/member/classes" class="btn btn-gradient gap-2 font-semibold">
                  <.icon name="hero-calendar-days-mini" class="size-4" /> Book a Class
                </.link>
              </div>
            </div>
          </div>
        </div>

        <%!-- Pending Invitations --%>
        <%= if @pending_invitations != [] do %>
          <div class="surface-2 accent-top relative overflow-hidden reveal" id="pending-invitations">
            <div class="p-6">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <span class="size-8 icon-tile icon-tile-primary"><.icon name="hero-envelope-solid" class="size-4" /></span>
                Pending Invitations
                <span class="badge badge-glow-primary badge-sm">{length(@pending_invitations)}</span>
              </h2>

              <div class="space-y-3 mt-4">
                <%= for inv <- @pending_invitations do %>
                  <div
                    class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-primary/5 border border-primary/15"
                    id={"invitation-#{inv.id}"}
                  >
                    <div class="flex items-center gap-4">
                      <div class="w-10 h-10 icon-tile icon-tile-primary shrink-0">
                        <.icon name="hero-building-office-2-solid" class="size-5" />
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
              <.empty_state
                icon="hero-building-office-2-solid"
                title="No Gym Membership"
                subtitle="You haven't joined any gym yet. Ask a gym operator to invite you as a member."
                icon_color="text-warning"
                icon_bg="bg-warning/10"
                action_label="Explore Gyms"
                action_href="/explore"
              />
            </div>
          <% end %>
        <% else %>
          <%!-- Stats Grid (rich cards with gradient accent + icon tile) --%>
          <div id="stats-grid" class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4" phx-hook="StaggerChildren" data-stagger="80">
            <.link
              navigate="/member/bookings"
              class="stat-card accent-top reveal block p-4 sm:p-5"
              id="stat-bookings"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">Bookings</p>
                  <p
                    id="counter-bookings"
                    class="text-2xl sm:text-3xl font-black mt-1"
                    phx-hook="AnimatedCounter"
                    data-target={@booking_count}
                  >0</p>
                </div>
                <div class="w-11 h-11 sm:w-12 sm:h-12 icon-tile icon-tile-info">
                  <.icon name="hero-ticket-solid" class="size-5 sm:size-6" />
                </div>
              </div>
              <p class="text-xs text-base-content/40 mt-3">Active bookings</p>
            </.link>

            <.link
              navigate="/member/attendance"
              class="stat-card accent-top reveal block p-4 sm:p-5"
              id="stat-attendance"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">Attendance</p>
                  <p
                    id="counter-attendance"
                    class="text-2xl sm:text-3xl font-black mt-1"
                    phx-hook="AnimatedCounter"
                    data-target={@attendance_count}
                  >0</p>
                </div>
                <div class="w-11 h-11 sm:w-12 sm:h-12 icon-tile icon-tile-success">
                  <.icon name="hero-check-badge-solid" class="size-5 sm:size-6" />
                </div>
              </div>
              <p class="text-xs text-base-content/40 mt-3">This month</p>
            </.link>

            <.link
              navigate="/member/workout"
              class="stat-card accent-top reveal block p-4 sm:p-5"
              id="stat-workout"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">Workout</p>
                  <p class="text-2xl sm:text-3xl font-black mt-1">
                    {if @workout_plan, do: length(@workout_plan.exercises || []), else: "--"}
                  </p>
                </div>
                <div class="w-11 h-11 sm:w-12 sm:h-12 icon-tile icon-tile-accent">
                  <.icon name="hero-fire-solid" class="size-5 sm:size-6" />
                </div>
              </div>
              <p class="text-xs text-base-content/40 mt-3">Exercises</p>
            </.link>

            <.link
              navigate="/member/diet"
              class="stat-card accent-top reveal block p-4 sm:p-5"
              id="stat-calories"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">Calories</p>
                  <p class="text-2xl sm:text-3xl font-black mt-1">
                    {if @diet_plan && @diet_plan.calorie_target,
                      do: @diet_plan.calorie_target,
                      else: "--"}
                  </p>
                </div>
                <div class="w-11 h-11 sm:w-12 sm:h-12 icon-tile icon-tile-warning">
                  <.icon name="hero-heart-solid" class="size-5 sm:size-6" />
                </div>
              </div>
              <p class="text-xs text-base-content/40 mt-3">Daily target</p>
            </.link>
          </div>
          <%!-- Main Content Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
            <%!-- My Workout Plan --%>
            <div class="surface-2 accent-top relative overflow-hidden hover-lift reveal" id="my-workout">
              <div class="p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <span class="size-8 icon-tile icon-tile-accent"><.icon name="hero-fire-solid" class="size-4" /></span>
                    My Workout Plan
                  </h2>
                  <.link navigate="/member/workout" class="btn btn-ghost btn-xs gap-1 hover-icon-move">
                    View Full Plan <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @workout_plan do %>
                    <div class="space-y-2">
                      <p class="font-semibold">{@workout_plan.name}</p>
                      <p class="text-sm text-base-content/60">
                        {length(@workout_plan.exercises || [])} exercises
                      </p>
                    </div>
                  <% else %>
                    <.empty_state
                      icon="hero-fire"
                      title="No Workout Plan Yet"
                      subtitle="Your gym operator will assign a workout plan tailored for you."
                      icon_color="text-accent"
                      icon_bg="bg-accent/10"
                    />
                  <% end %>
                </div>
              </div>
            </div>
            <%!-- My Diet Plan --%>
            <div class="surface-2 accent-top relative overflow-hidden hover-lift reveal" id="my-diet">
              <div class="p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <span class="size-8 icon-tile icon-tile-success"><.icon name="hero-heart-solid" class="size-4" /></span>
                    My Diet Plan
                  </h2>
                  <.link navigate="/member/diet" class="btn btn-ghost btn-xs gap-1 hover-icon-move">
                    View Full Plan <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @diet_plan do %>
                    <div class="space-y-2">
                      <p class="font-semibold">{@diet_plan.name}</p>
                      <%= if @diet_plan.calorie_target do %>
                        <p class="text-sm text-base-content/60">
                          {@diet_plan.calorie_target} kcal/day target
                        </p>
                      <% end %>
                    </div>
                  <% else %>
                    <.empty_state
                      icon="hero-heart"
                      title="No Diet Plan Yet"
                      subtitle="Your gym operator will create a nutrition plan based on your goals."
                      icon_color="text-success"
                      icon_bg="bg-success/10"
                    />
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          <%!-- Upcoming Bookings & Subscription --%>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
            <%!-- Upcoming Bookings --%>
            <div class="lg:col-span-2 surface-2 accent-top relative overflow-hidden reveal" id="upcoming-bookings">
              <div class="p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <span class="size-8 icon-tile icon-tile-info"><.icon name="hero-calendar-days-solid" class="size-4" /></span>
                    Upcoming Bookings
                  </h2>
                  <.link navigate="/member/classes" class="btn btn-ghost btn-xs gap-1">
                    Browse Classes <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @upcoming_bookings == [] do %>
                    <div class="flex items-center gap-3 p-4 rounded-xl bg-primary/5 border border-primary/10">
                      <.icon name="hero-calendar" class="size-5 text-primary/60" />
                      <p class="text-sm text-base-content/60">
                        No upcoming bookings.
                        <.link navigate="/member/classes" class="text-primary font-semibold hover:underline">
                          Browse available classes
                        </.link>
                      </p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto rounded-xl border border-base-300/50">
                      <table class="table table-sm table-fancy m-0">
                        <thead>
                          <tr>
                            <th>Class</th>
                            <th>Date & Time</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for booking <- @upcoming_bookings do %>
                            <tr>
                              <td class="font-semibold">
                                {booking.scheduled_class.class_definition.name}
                              </td>
                              <td class="text-base-content/70">
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
            <div class="surface-2 accent-top relative overflow-hidden reveal" id="subscription-status">
              <div class="p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <span class="size-8 icon-tile icon-tile-warning"><.icon name="hero-credit-card-solid" class="size-4" /></span>
                  Subscription
                </h2>

                <div class="mt-4">
                  <%= if @subscription do %>
                    <div class="space-y-3">
                      <div class="px-3 py-2 rounded-xl bg-success/10 border border-success/25 inline-flex items-center gap-2">
                        <.icon name="hero-check-circle-solid" class="size-4 text-success" />
                        <span class="text-sm font-bold text-success">Active</span>
                      </div>
                      <p class="font-semibold text-base">{@subscription.subscription_plan.name}</p>
                      <p class="text-xs text-base-content/50">
                        Expires: {Calendar.strftime(@subscription.ends_at, "%b %d, %Y")}
                      </p>
                    </div>
                  <% else %>
                    <div class="p-5 rounded-xl bg-warning/5 border border-warning/15 text-center">
                      <div class="w-14 h-14 icon-tile icon-tile-warning mx-auto mb-3">
                        <.icon name="hero-credit-card" class="size-7" />
                      </div>
                      <p class="text-sm font-semibold">No Active Subscription</p>
                      <p class="text-xs text-base-content/50 mt-1">
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
