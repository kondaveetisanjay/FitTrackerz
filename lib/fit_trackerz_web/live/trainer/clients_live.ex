defmodule FitTrackerzWeb.Trainer.ClientsLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case FitTrackerz.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
      {:ok, trainers} -> trainers
      _ -> []
    end

    if gym_trainers == [] do
      {:ok,
       socket
       |> assign(page_title: "My Clients")
       |> assign(no_gym: true, clients: [], all_clients: [], gyms: [], pending_requests: [], search: "")}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)
      trainer_ids = Enum.map(gym_trainers, & &1.id)

      clients = case FitTrackerz.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user, :gym]) do
        {:ok, members} -> members
        _ -> []
      end

      pending_requests = case FitTrackerz.Gym.list_pending_assignments_by_trainer(trainer_ids, actor: actor) do
        {:ok, requests} -> requests
        _ -> []
      end

      {:ok,
       socket
       |> assign(page_title: "My Clients")
       |> assign(
         no_gym: false,
         clients: clients,
         all_clients: clients,
         gyms: gyms,
         trainer_ids: trainer_ids,
         pending_requests: pending_requests,
         search: ""
       )}
    end
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    q = String.downcase(search)
    clients = if q == "" do
      socket.assigns.all_clients
    else
      Enum.filter(socket.assigns.all_clients, fn c ->
        String.contains?(String.downcase(c.user.name || ""), q) or
          String.contains?(String.downcase(to_string(c.user.email)), q) or
          String.contains?(String.downcase(c.gym.name || ""), q)
      end)
    end

    {:noreply, assign(socket, search: search, clients: clients)}
  end

  def handle_event("accept_request", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_assignment_request(id, actor: actor) do
      {:ok, request} ->
        case FitTrackerz.Gym.accept_assignment_request(request, actor: actor) do
          {:ok, _} ->
            # Reload clients and pending requests
            {clients, pending_requests} = reload_data(socket)

            {:noreply,
             socket
             |> put_flash(:info, "Client accepted! They are now assigned to you.")
             |> assign(clients: clients, all_clients: clients, pending_requests: pending_requests)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to accept assignment.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Request not found.")}
    end
  end

  def handle_event("reject_request", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_assignment_request(id, actor: actor) do
      {:ok, request} ->
        case FitTrackerz.Gym.reject_assignment_request(request, actor: actor) do
          {:ok, _} ->
            {clients, pending_requests} = reload_data(socket)

            {:noreply,
             socket
             |> put_flash(:info, "Assignment request rejected.")
             |> assign(clients: clients, all_clients: clients, pending_requests: pending_requests)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to reject assignment.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Request not found.")}
    end
  end

  defp reload_data(socket) do
    actor = socket.assigns.current_user
    trainer_ids = socket.assigns.trainer_ids

    clients = case FitTrackerz.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user, :gym]) do
      {:ok, members} -> members
      _ -> []
    end

    pending_requests = case FitTrackerz.Gym.list_pending_assignments_by_trainer(trainer_ids, actor: actor) do
      {:ok, requests} -> requests
      _ -> []
    end

    {clients, pending_requests}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="My Clients" subtitle="View and manage your assigned members." back_path="/trainer/dashboard" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-exclamation-triangle"
          title="No Gym Association"
          subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%!-- Pending Requests --%>
        <%= if @pending_requests != [] do %>
          <div class="mb-8" id="pending-requests-card">
            <.alert variant="info">
              You have {length(@pending_requests)} pending client assignment request(s).
            </.alert>
            <div class="mt-4 space-y-3">
              <div
                :for={request <- @pending_requests}
                id={"request-#{request.id}"}
                class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-xl bg-base-100 border border-base-300/50"
              >
                <div class="flex items-center gap-3">
                  <.avatar name={request.member.user.name || "M"} size="sm" />
                  <div>
                    <p class="font-semibold text-sm">{request.member.user.name}</p>
                    <p class="text-xs text-base-content/50">{request.member.user.email}</p>
                    <p class="text-xs text-base-content/40 mt-0.5">
                      Gym: {request.gym.name} &middot; Requested by: {request.requested_by.name}
                    </p>
                  </div>
                </div>
                <div class="flex items-center gap-2">
                  <.button
                    variant="primary"
                    size="sm"
                    icon="hero-check"
                    phx-click="accept_request"
                    phx-value-id={request.id}
                    id={"accept-#{request.id}"}
                  >
                    Accept
                  </.button>
                  <.button
                    variant="danger"
                    size="sm"
                    icon="hero-x-mark"
                    phx-click="reject_request"
                    phx-value-id={request.id}
                    id={"reject-#{request.id}"}
                  >
                    Reject
                  </.button>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Stats --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-8">
          <.stat_card label="Total Clients" value={length(@clients)} icon="hero-user-group-solid" color="primary" />
          <.stat_card label="Active" value={Enum.count(@clients, & &1.is_active)} icon="hero-check-circle-solid" color="success" />
          <.stat_card label="Pending Requests" value={length(@pending_requests)} icon="hero-inbox-solid" color="info" />
        </div>

        <%!-- Search + Table --%>
        <.card title="Assigned Clients">
          <.filter_bar
            search_placeholder="Search by name, email, or gym..."
            search_value={@search}
            on_search="search"
          />

          <%= if @clients == [] do %>
            <.empty_state
              icon="hero-user-group"
              title={if @search != "", do: "No clients match your search", else: "No clients assigned yet"}
              subtitle={if @search != "", do: "Try adjusting your search terms.", else: "Members will appear here once you accept assignment requests."}
            />
          <% else %>
            <.data_table id="clients-table" rows={@clients} row_id={fn client -> "client-#{client.id}" end}>
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
              <:mobile_card :let={client}>
                <div class="flex items-center gap-3">
                  <.avatar name={client.user.name} size="sm" />
                  <div>
                    <p class="font-semibold">{client.user.name}</p>
                    <p class="text-xs text-base-content/50">{client.gym.name}</p>
                  </div>
                  <div class="ml-auto">
                    <%= if client.is_active do %>
                      <.badge variant="success">Active</.badge>
                    <% else %>
                      <.badge variant="neutral">Inactive</.badge>
                    <% end %>
                  </div>
                </div>
              </:mobile_card>
            </.data_table>
          <% end %>
        </.card>
      <% end %>
    </Layouts.app>
    """
  end
end
