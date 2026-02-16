defmodule FitconnexWeb.Trainer.ClientsLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case Fitconnex.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
      {:ok, trainers} -> trainers
      _ -> []
    end

    if gym_trainers == [] do
      {:ok,
       socket
       |> assign(page_title: "My Clients")
       |> assign(no_gym: true, clients: [], gyms: [])}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)
      trainer_ids = Enum.map(gym_trainers, & &1.id)

      clients = case Fitconnex.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user, :gym]) do
        {:ok, members} -> members
        _ -> []
      end

      {:ok,
       socket
       |> assign(page_title: "My Clients")
       |> assign(no_gym: false, clients: clients, gyms: gyms)}
    end
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

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-gyms">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Gyms
                    </p>
                    <p class="text-3xl font-black mt-1">{length(@gyms)}</p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-building-office-2-solid" class="size-6 text-info" />
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
                          No clients assigned yet. Members will appear here once assigned by the gym operator.
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
