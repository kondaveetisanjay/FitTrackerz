defmodule FitTrackerzWeb.Trainer.DashboardLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    {:ok, load_dashboard(socket, actor)}
  end

  defp load_dashboard(socket, actor) do
    pending_invitations = case FitTrackerz.Gym.list_pending_trainer_invitations(actor.email, actor: actor, load: [:gym, :invited_by]) do
      {:ok, invitations} -> invitations
      _ -> []
    end

    gym_trainers = case FitTrackerz.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
      {:ok, trainers} -> trainers
      _ -> []
    end

    gym_trainer_ids = Enum.map(gym_trainers, & &1.id)

    client_requests = if gym_trainer_ids != [] do
      case FitTrackerz.Gym.list_pending_assignments_by_trainer(gym_trainer_ids, actor: actor, load: [:gym, :requested_by, member: [:user]]) do
        {:ok, requests} -> requests
        _ -> []
      end
    else
      []
    end

    if gym_trainers == [] do
      socket
      |> assign(
        page_title: "Trainer Dashboard",
        no_gym: true,
        pending_invitations: pending_invitations,
        client_requests: client_requests,
        client_count: 0,
        class_count: 0,
        workout_count: 0,
        diet_count: 0,
        clients: [],
        upcoming_classes: []
      )
    else
      clients = case FitTrackerz.Gym.list_members_by_trainer(gym_trainer_ids, actor: actor, load: [:user, :gym]) do
        {:ok, members} -> members
        _ -> []
      end

      classes = case FitTrackerz.Scheduling.list_classes_by_trainer(gym_trainer_ids, actor: actor, load: [:class_definition, :branch]) do
        {:ok, classes} -> classes
        _ -> []
      end

      workouts = case FitTrackerz.Training.list_workouts_by_trainer(gym_trainer_ids, actor: actor) do
        {:ok, workouts} -> workouts
        _ -> []
      end

      diets = case FitTrackerz.Training.list_diets_by_trainer(gym_trainer_ids, actor: actor) do
        {:ok, diets} -> diets
        _ -> []
      end

      socket
      |> assign(
        page_title: "Trainer Dashboard",
        no_gym: false,
        pending_invitations: pending_invitations,
        client_requests: client_requests,
        client_count: length(clients),
        class_count: length(classes),
        workout_count: length(workouts),
        diet_count: length(diets),
        clients: Enum.take(clients, 5),
        upcoming_classes: Enum.take(classes, 5)
      )
    end
  end

  @impl true
  def handle_event("accept-invitation", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_trainer_invitation(id, actor: actor, load: [:gym]) do
      {:ok, invitation} ->
        case FitTrackerz.Gym.accept_trainer_invitation(invitation, %{}, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Invitation accepted! You've been added to #{invitation.gym.name}.")
             |> load_dashboard(actor)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to accept invitation. Please try again.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invitation not found.")}
    end
  end

  def handle_event("accept-client-request", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_assignment_request(id, actor: actor, load: [:gym, member: [:user]]) do
      {:ok, request} ->
        case FitTrackerz.Gym.accept_assignment_request(request, %{}, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Client assignment accepted! #{request.member.user.name} is now your client.")
             |> load_dashboard(actor)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to accept client assignment. Please try again.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Client assignment request not found.")}
    end
  end

  def handle_event("reject-client-request", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_assignment_request(id, actor: actor) do
      {:ok, request} ->
        case FitTrackerz.Gym.reject_assignment_request(request, %{}, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Client assignment declined.")
             |> load_dashboard(actor)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to decline client assignment. Please try again.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Client assignment request not found.")}
    end
  end

  @impl true
  def handle_event("reject-invitation", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_trainer_invitation(id, actor: actor) do
      {:ok, invitation} ->
        case FitTrackerz.Gym.reject_trainer_invitation(invitation, %{}, actor: actor) do
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
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Trainer Dashboard</h1>

            <p class="text-base-content/50 mt-1">
              Manage your clients, classes, and training programs.
            </p>
          </div>

          <div class="flex gap-2">
            <.link navigate="/trainer/workouts" class="btn btn-primary btn-sm gap-2 font-semibold">
              <.icon name="hero-plus-mini" class="size-4" /> New Workout Plan
            </.link>
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

        <%!-- Client Assignment Requests --%>
        <%= if @client_requests != [] do %>
          <div class="card bg-base-200/50 border border-info/30" id="client-requests">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-user-plus-solid" class="size-5 text-info" />
                Client Assignment Requests
                <span class="badge badge-info badge-sm">{length(@client_requests)}</span>
              </h2>

              <div class="space-y-3 mt-4">
                <%= for req <- @client_requests do %>
                  <div
                    class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-base-300/30 border border-base-300/50"
                    id={"client-request-#{req.id}"}
                  >
                    <div class="flex items-center gap-4">
                      <div class="w-10 h-10 rounded-xl bg-info/10 flex items-center justify-center shrink-0">
                        <.icon name="hero-user-solid" class="size-5 text-info" />
                      </div>

                      <div>
                        <p class="font-semibold">{req.member.user.name}</p>

                        <p class="text-sm text-base-content/50">
                          {req.member.user.email} &bull; {req.gym.name}
                        </p>

                        <p class="text-xs text-base-content/40">
                          Requested by {req.requested_by.name} &bull; {Calendar.strftime(req.inserted_at, "%b %d, %Y")}
                        </p>
                      </div>
                    </div>

                    <div class="flex gap-2 sm:shrink-0">
                      <button
                        phx-click="accept-client-request"
                        phx-value-id={req.id}
                        class="btn btn-success btn-sm gap-1 font-semibold"
                      >
                        <.icon name="hero-check-mini" class="size-4" /> Accept
                      </button>

                      <button
                        phx-click="reject-client-request"
                        phx-value-id={req.id}
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
                  <.icon name="hero-academic-cap-solid" class="size-10 text-warning" />
                </div>

                <h2 class="text-xl font-black tracking-tight">No Gym Association</h2>

                <p class="text-base-content/50 mt-3">
                  You haven't been added to any gym yet. Ask a gym operator to invite you as a trainer.
                </p>
              </div>
            </div>
          <% end %>
        <% else %>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <.link
              navigate="/trainer/clients"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-clients"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      My Clients
                    </p>

                    <p class="text-3xl font-black mt-1">{@client_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-user-group-solid" class="size-6 text-primary" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Assigned members</p>
              </div>
            </.link>
            <.link
              navigate="/trainer/classes"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-upcoming-classes"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Upcoming Classes
                    </p>

                    <p class="text-3xl font-black mt-1">{@class_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-calendar-days-solid" class="size-6 text-info" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Scheduled</p>
              </div>
            </.link>
            <.link
              navigate="/trainer/workouts"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-workout-plans"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Workout Plans
                    </p>

                    <p class="text-3xl font-black mt-1">{@workout_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-accent/10 flex items-center justify-center">
                    <.icon name="hero-fire-solid" class="size-6 text-accent" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Created plans</p>
              </div>
            </.link>
            <.link
              navigate="/trainer/diets"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-diet-plans"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Diet Plans
                    </p>

                    <p class="text-3xl font-black mt-1">{@diet_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-success/10 flex items-center justify-center">
                    <.icon name="hero-heart-solid" class="size-6 text-success" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Active plans</p>
              </div>
            </.link>
          </div>
          <%!-- Main Content Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Quick Actions --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="quick-actions">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-bolt-solid" class="size-5 text-primary" /> Quick Actions
                </h2>

                <div class="space-y-2 mt-4">
                  <.link
                    navigate="/trainer/workouts"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-fire" class="size-4 text-accent" /> New Workout
                  </.link>
                  <.link
                    navigate="/trainer/diets"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-heart" class="size-4 text-success" /> New Diet Plan
                  </.link>
                  <.link
                    navigate="/trainer/templates"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-document-duplicate" class="size-4 text-info" /> Templates
                  </.link>
                  <.link
                    navigate="/trainer/attendance"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-clipboard-document-check" class="size-4 text-warning" />
                    Mark Attendance
                  </.link>
                </div>
              </div>
            </div>
            <%!-- Upcoming Classes --%>
            <div
              class="lg:col-span-2 card bg-base-200/50 border border-base-300/50"
              id="upcoming-classes-card"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <.icon name="hero-calendar-solid" class="size-5 text-info" /> Upcoming Classes
                  </h2>

                  <.link navigate="/trainer/classes" class="btn btn-ghost btn-xs gap-1">
                    View All <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @upcoming_classes == [] do %>
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                      <.icon name="hero-calendar" class="size-5 text-base-content/30" />
                      <p class="text-sm text-base-content/50">No upcoming classes scheduled.</p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="table table-sm">
                        <thead>
                          <tr class="text-base-content/40">
                            <th>Class</th>

                            <th>Location</th>

                            <th>Scheduled</th>

                            <th>Duration</th>
                          </tr>
                        </thead>

                        <tbody>
                          <%= for sc <- @upcoming_classes do %>
                            <tr>
                              <td class="font-medium">{sc.class_definition.name}</td>

                              <td class="text-base-content/60">
                                {if sc.branch, do: sc.branch.city, else: "N/A"}
                              </td>

                              <td class="text-base-content/60">
                                {Calendar.strftime(sc.scheduled_at, "%b %d, %H:%M")}
                              </td>

                              <td>{sc.duration_minutes} min</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          <%!-- Clients List --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="client-list">
            <div class="card-body p-5">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-user-group-solid" class="size-5 text-primary" /> My Clients
                </h2>

                <.link navigate="/trainer/clients" class="btn btn-ghost btn-xs gap-1">
                  View All <.icon name="hero-arrow-right-mini" class="size-3" />
                </.link>
              </div>

              <div class="mt-4">
                <%= if @clients == [] do %>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <.icon name="hero-user-group" class="size-5 text-base-content/30" />
                    <p class="text-sm text-base-content/50">
                      No clients assigned yet. Members will appear here once assigned by the gym operator.
                    </p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr class="text-base-content/40">
                          <th>Name</th>

                          <th>Email</th>

                          <th>Gym</th>

                          <th>Status</th>
                        </tr>
                      </thead>

                      <tbody>
                        <%= for client <- @clients do %>
                          <tr>
                            <td class="font-medium">{client.user.name}</td>

                            <td class="text-base-content/60">{client.user.email}</td>

                            <td class="text-base-content/60">{client.gym.name}</td>

                            <td>
                              <%= if client.is_active do %>
                                <span class="badge badge-success badge-sm">Active</span>
                              <% else %>
                                <span class="badge badge-ghost badge-sm">Inactive</span>
                              <% end %>
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
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
