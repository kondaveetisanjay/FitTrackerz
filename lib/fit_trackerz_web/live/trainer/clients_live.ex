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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">My Clients</h1>
              <p class="text-base-content/50 mt-1">View and manage your assigned members.</p>
            </div>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-notice">
            <div class="card-body p-8 items-center text-center">
              <div class="w-16 h-16 rounded-full bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-exclamation-triangle-solid" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Association</h2>
              <p class="text-base-content/50 mt-2 max-w-md">
                You haven't been added to any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Pending Requests --%>
          <%= if @pending_requests != [] do %>
            <div class="card bg-info/5 border border-info/20" id="pending-requests-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 text-info">
                  <.icon name="hero-inbox-solid" class="size-5" />
                  Pending Assignment Requests
                  <span class="badge badge-info badge-sm">{length(@pending_requests)}</span>
                </h2>
                <p class="text-sm text-base-content/50 mt-1">
                  The gym operator has requested you to train these members. Accept or reject below.
                </p>
                <div class="mt-4 space-y-3">
                  <div
                    :for={request <- @pending_requests}
                    id={"request-#{request.id}"}
                    class="flex items-center justify-between p-4 rounded-lg bg-base-100 border border-base-300/50"
                  >
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 rounded-full bg-primary/15 flex items-center justify-center">
                        <span class="text-sm font-bold text-primary">
                          {String.first(request.member.user.name || "M")}
                        </span>
                      </div>
                      <div>
                        <p class="font-semibold text-sm">{request.member.user.name}</p>
                        <p class="text-xs text-base-content/50">{request.member.user.email}</p>
                        <p class="text-xs text-base-content/40 mt-0.5">
                          Gym: {request.gym.name}
                          <span class="mx-1">&middot;</span>
                          Requested by: {request.requested_by.name}
                        </p>
                      </div>
                    </div>
                    <div class="flex items-center gap-2">
                      <button
                        phx-click="accept_request"
                        phx-value-id={request.id}
                        class="btn btn-success btn-sm gap-1"
                        id={"accept-#{request.id}"}
                      >
                        <.icon name="hero-check-mini" class="size-4" /> Accept
                      </button>
                      <button
                        phx-click="reject_request"
                        phx-value-id={request.id}
                        class="btn btn-ghost btn-sm gap-1 text-error"
                        id={"reject-#{request.id}"}
                      >
                        <.icon name="hero-x-mark-mini" class="size-4" /> Reject
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Search --%>
          <div id="clients-search">
            <div class="relative">
              <.icon name="hero-magnifying-glass-mini" class="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40" />
              <input
                type="text"
                placeholder="Search by name, email, or gym..."
                value={@search}
                phx-keyup="search"
                phx-key="Enter"
                phx-debounce="300"
                name="search"
                class="input input-bordered input-sm w-full sm:w-80 pl-9"
                id="client-search-input"
              />
            </div>
          </div>

          <%!-- Stats --%>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-total-clients">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Total Clients
                    </p>
                    <p class="text-3xl font-black mt-1">{length(@clients)}</p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-user-group-solid" class="size-6 text-primary" />
                  </div>
                </div>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-active-clients">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Active
                    </p>
                    <p class="text-3xl font-black mt-1">{Enum.count(@clients, & &1.is_active)}</p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-success/10 flex items-center justify-center">
                    <.icon name="hero-check-circle-solid" class="size-6 text-success" />
                  </div>
                </div>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-pending">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Pending Requests
                    </p>
                    <p class="text-3xl font-black mt-1">{length(@pending_requests)}</p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-inbox-solid" class="size-6 text-info" />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Clients Table --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="clients-table-card">
            <div class="card-body p-5">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-user-group-solid" class="size-5 text-primary" /> Assigned Clients
              </h2>
              <div class="mt-4 overflow-x-auto">
                <table class="table table-sm" id="clients-table">
                  <thead>
                    <tr class="text-base-content/40">
                      <th>Name</th>
                      <th>Email</th>
                      <th>Gym</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @clients == [] do %>
                      <tr id="clients-empty-row">
                        <td colspan="4" class="text-center text-base-content/40 py-8">
                          <%= if @search != "" do %>
                            No clients match your search.
                          <% else %>
                            No clients assigned yet. Members will appear here once you accept assignment requests.
                          <% end %>
                        </td>
                      </tr>
                    <% else %>
                      <tr :for={client <- @clients} id={"client-#{client.id}"}>
                        <td class="font-medium">{client.user.name}</td>
                        <td class="text-base-content/60">{client.user.email}</td>
                        <td class="text-base-content/60">{client.gym.name}</td>
                        <td>
                          <%= if client.is_active do %>
                            <span class="badge badge-success badge-sm gap-1">
                              <.icon name="hero-check-circle-mini" class="size-3" /> Active
                            </span>
                          <% else %>
                            <span class="badge badge-ghost badge-sm gap-1">
                              <.icon name="hero-x-circle-mini" class="size-3" /> Inactive
                            </span>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
