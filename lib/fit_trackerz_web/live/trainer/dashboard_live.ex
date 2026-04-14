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
      <.page_header title="Trainer Dashboard" subtitle="Manage your clients, classes, and training programs.">
        <:actions>
          <.button variant="primary" size="sm" icon="hero-plus" navigate="/trainer/workouts">
            New Workout Plan
          </.button>
        </:actions>
      </.page_header>

      <%!-- Pending Invitations --%>
      <%= if @pending_invitations != [] do %>
        <.section title="Pending Invitations">
          <.card>
            <div class="space-y-3">
              <%= for inv <- @pending_invitations do %>
                <div
                  class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-base-200/50 border border-base-300/50"
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
        </.section>
      <% end %>

      <%!-- Client Assignment Requests --%>
      <%= if @client_requests != [] do %>
        <.section title="Client Assignment Requests">
          <.alert variant="info">
            You have {length(@client_requests)} pending client assignment request(s).
          </.alert>
          <div class="space-y-3 mt-4">
            <%= for req <- @client_requests do %>
              <div
                class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-base-200/50 border border-base-300/50"
                id={"client-request-#{req.id}"}
              >
                <div class="flex items-center gap-4">
                  <.avatar name={req.member.user.name} size="sm" />
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
                  <.button variant="primary" size="sm" icon="hero-check" phx-click="accept-client-request" phx-value-id={req.id}>
                    Accept
                  </.button>
                  <.button variant="ghost" size="sm" icon="hero-x-mark" phx-click="reject-client-request" phx-value-id={req.id}>
                    Decline
                  </.button>
                </div>
              </div>
            <% end %>
          </div>
        </.section>
      <% end %>

      <%= if @no_gym do %>
        <%= if @pending_invitations == [] do %>
          <.empty_state
            icon="hero-academic-cap"
            title="No Gym Association"
            subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you as a trainer."
          />
        <% end %>
      <% else %>
        <%!-- Stats Grid --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-8">
          <.link navigate="/trainer/clients">
            <.stat_card label="My Clients" value={@client_count} icon="hero-user-group-solid" color="primary" />
          </.link>
          <.link navigate="/trainer/classes">
            <.stat_card label="Upcoming Classes" value={@class_count} icon="hero-calendar-days-solid" color="info" />
          </.link>
          <.link navigate="/trainer/workouts">
            <.stat_card label="Workout Plans" value={@workout_count} icon="hero-fire-solid" color="accent" />
          </.link>
          <.link navigate="/trainer/diets">
            <.stat_card label="Diet Plans" value={@diet_count} icon="hero-heart-solid" color="success" />
          </.link>
        </div>

        <%!-- Main Content Grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <%!-- Quick Actions --%>
          <.card title="Quick Actions">
            <div class="space-y-2">
              <.button variant="ghost" size="sm" icon="hero-fire" navigate="/trainer/workouts" class="w-full justify-start">
                New Workout
              </.button>
              <.button variant="ghost" size="sm" icon="hero-heart" navigate="/trainer/diets" class="w-full justify-start">
                New Diet Plan
              </.button>
              <.button variant="ghost" size="sm" icon="hero-document-duplicate" navigate="/trainer/templates" class="w-full justify-start">
                Templates
              </.button>
              <.button variant="ghost" size="sm" icon="hero-clipboard-document-check" navigate="/trainer/attendance" class="w-full justify-start">
                Mark Attendance
              </.button>
            </div>
          </.card>

          <%!-- Upcoming Classes --%>
          <div class="lg:col-span-2">
            <.card title="Upcoming Classes">
              <:header_actions>
                <.button variant="ghost" size="sm" navigate="/trainer/classes">
                  View All
                </.button>
              </:header_actions>
              <%= if @upcoming_classes == [] do %>
                <.empty_state
                  icon="hero-calendar"
                  title="No upcoming classes"
                  subtitle="No upcoming classes scheduled."
                />
              <% else %>
                <.data_table id="dashboard-classes" rows={@upcoming_classes}>
                  <:col :let={sc} label="Class">
                    <span class="font-medium">{sc.class_definition.name}</span>
                  </:col>
                  <:col :let={sc} label="Location">
                    {if sc.branch, do: sc.branch.city, else: "N/A"}
                  </:col>
                  <:col :let={sc} label="Scheduled">
                    {Calendar.strftime(sc.scheduled_at, "%b %d, %H:%M")}
                  </:col>
                  <:col :let={sc} label="Duration">
                    {sc.duration_minutes} min
                  </:col>
                </.data_table>
              <% end %>
            </.card>
          </div>
        </div>

        <%!-- Clients List --%>
        <.card title="My Clients">
          <:header_actions>
            <.button variant="ghost" size="sm" navigate="/trainer/clients">
              View All
            </.button>
          </:header_actions>
          <%= if @clients == [] do %>
            <.empty_state
              icon="hero-user-group"
              title="No clients assigned"
              subtitle="Members will appear here once assigned by the gym operator."
            />
          <% else %>
            <.data_table id="dashboard-clients" rows={@clients}>
              <:col :let={client} label="Name">
                <div class="flex items-center gap-2">
                  <.avatar name={client.user.name} size="sm" />
                  <span class="font-medium">{client.user.name}</span>
                </div>
              </:col>
              <:col :let={client} label="Email">
                {client.user.email}
              </:col>
              <:col :let={client} label="Gym">
                {client.gym.name}
              </:col>
              <:col :let={client} label="Status">
                <%= if client.is_active do %>
                  <.badge variant="success">Active</.badge>
                <% else %>
                  <.badge variant="neutral">Inactive</.badge>
                <% end %>
              </:col>
            </.data_table>
          <% end %>
        </.card>
      <% end %>
    </Layouts.app>
    """
  end
end
