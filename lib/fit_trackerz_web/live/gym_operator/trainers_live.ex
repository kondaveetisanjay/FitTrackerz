defmodule FitTrackerzWeb.GymOperator.TrainersLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        trainers = load_trainers(gym.id, actor)
        members = load_members(gym.id, actor)
        trainer_member_map = build_trainer_member_map(members)

        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:ok,
         assign(socket,
           page_title: "Trainers",
           gym: gym,
           trainers: trainers,
           all_trainers: trainers,
           trainer_member_map: trainer_member_map,
           invite_form: invite_form,
           show_invite: false,
           search: "",
           filter_status: "all",
           expanded_trainer_id: nil
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Trainers",
           gym: nil,
           trainers: [],
           all_trainers: [],
           trainer_member_map: %{},
           invite_form: nil,
           show_invite: false,
           search: "",
           filter_status: "all",
           expanded_trainer_id: nil
         )}
    end
  end

  @impl true
  def handle_event("toggle_invite", _params, socket) do
    {:noreply, assign(socket, show_invite: !socket.assigns.show_invite)}
  end

  def handle_event("validate_invite", %{"invite" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("invite", %{"invite" => %{"email" => email}}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    case FitTrackerz.Gym.create_trainer_invitation(%{
      invited_email: email,
      gym_id: gym.id,
      invited_by_id: actor.id
    }, actor: actor) do
      {:ok, _invitation} ->
        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:noreply,
         socket
         |> put_flash(:info, "Trainer invitation sent to #{email}!")
         |> assign(invite_form: invite_form, show_invite: false)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    trainer = Enum.find(socket.assigns.all_trainers, &(&1.id == id))

    if trainer do
      case FitTrackerz.Gym.update_gym_trainer(trainer, %{is_active: !trainer.is_active}, actor: actor) do
        {:ok, _updated} ->
          trainers = load_trainers(gym.id, actor)

          {:noreply,
           socket
           |> put_flash(:info, "Trainer status updated.")
           |> assign(all_trainers: trainers)
           |> apply_filters()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update trainer status.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Trainer not found.")}
    end
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(search: search)
     |> apply_filters()}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(filter_status: status)
     |> apply_filters()}
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    new_id = if socket.assigns.expanded_trainer_id == id, do: nil, else: id
    {:noreply, assign(socket, expanded_trainer_id: new_id)}
  end

  # ── Helpers ──

  defp load_trainers(gym_id, actor) do
    case FitTrackerz.Gym.list_trainers_by_gym(gym_id, actor: actor, load: [:user]) do
      {:ok, trainers} -> trainers
      _ -> []
    end
  end

  defp load_members(gym_id, actor) do
    case FitTrackerz.Gym.list_members_by_gym(gym_id, actor: actor, load: [:user]) do
      {:ok, members} -> members
      _ -> []
    end
  end

  defp build_trainer_member_map(members) do
    members
    |> Enum.filter(& &1.assigned_trainer_id)
    |> Enum.group_by(& &1.assigned_trainer_id)
  end

  defp apply_filters(socket) do
    trainers =
      socket.assigns.all_trainers
      |> filter_by_search(socket.assigns.search)
      |> filter_by_status(socket.assigns.filter_status)

    assign(socket, trainers: trainers)
  end

  defp filter_by_search(trainers, ""), do: trainers
  defp filter_by_search(trainers, search) do
    q = String.downcase(search)
    Enum.filter(trainers, fn t ->
      String.contains?(String.downcase(t.user.name || ""), q) or
        String.contains?(String.downcase(to_string(t.user.email)), q) or
        Enum.any?(t.specializations || [], &String.contains?(String.downcase(&1), q))
    end)
  end

  defp filter_by_status(trainers, "all"), do: trainers
  defp filter_by_status(trainers, "active"), do: Enum.filter(trainers, & &1.is_active)
  defp filter_by_status(trainers, "inactive"), do: Enum.reject(trainers, & &1.is_active)
  defp filter_by_status(trainers, _), do: trainers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Trainers</h1>
              <p class="text-base-content/50 mt-1">Manage your gym trainers and invite new ones.</p>
            </div>
          </div>
          <%= if @gym do %>
            <button
              phx-click="toggle_invite"
              class="btn btn-primary btn-sm gap-2 font-semibold"
              id="toggle-trainer-invite-btn"
            >
              <.icon name="hero-academic-cap-mini" class="size-4" /> Invite Trainer
            </button>
          <% end %>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before managing trainers.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Invite Form --%>
          <%= if @show_invite do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="invite-trainer-card">
              <div class="card-body p-6">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-envelope-solid" class="size-5 text-secondary" />
                  Invite New Trainer
                </h2>
                <.form
                  for={@invite_form}
                  id="invite-trainer-form"
                  phx-change="validate_invite"
                  phx-submit="invite"
                >
                  <div class="flex gap-4 items-end">
                    <div class="flex-1">
                      <.input
                        field={@invite_form[:email]}
                        type="email"
                        label="Email Address"
                        placeholder="trainer@example.com"
                        required
                      />
                    </div>
                    <div class="mb-2">
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm gap-2"
                        id="send-trainer-invite-btn"
                      >
                        <.icon name="hero-paper-airplane" class="size-4" /> Send Invite
                      </button>
                    </div>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Search & Filter --%>
          <div class="flex flex-col sm:flex-row gap-3" id="trainers-search-filter">
            <div class="flex-1">
              <div class="relative">
                <.icon name="hero-magnifying-glass-mini" class="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40" />
                <input
                  type="text"
                  placeholder="Search by name, email, or specialization..."
                  value={@search}
                  phx-keyup="search"
                  phx-key="Enter"
                  phx-debounce="300"
                  name="search"
                  class="input input-bordered input-sm w-full pl-9"
                  id="trainer-search-input"
                />
              </div>
            </div>
            <div class="flex gap-2">
              <button
                phx-click="filter_status"
                phx-value-status="all"
                class={"btn btn-sm #{if @filter_status == "all", do: "btn-primary", else: "btn-ghost"}"}
              >
                All <span class="badge badge-sm ml-1">{length(@all_trainers)}</span>
              </button>
              <button
                phx-click="filter_status"
                phx-value-status="active"
                class={"btn btn-sm #{if @filter_status == "active", do: "btn-success", else: "btn-ghost"}"}
              >
                Active
              </button>
              <button
                phx-click="filter_status"
                phx-value-status="inactive"
                class={"btn btn-sm #{if @filter_status == "inactive", do: "btn-error", else: "btn-ghost"}"}
              >
                Inactive
              </button>
            </div>
          </div>

          <%!-- Trainers Table --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="trainers-table-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-academic-cap-solid" class="size-5 text-secondary" /> All Trainers
                <span class="badge badge-neutral badge-sm">{length(@trainers)}</span>
              </h2>
              <%= if @trainers == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                  <p class="text-sm text-base-content/50">
                    <%= if @search != "" or @filter_status != "all" do %>
                      No trainers match your filters.
                    <% else %>
                      No trainers yet. Invite trainers to build your team!
                    <% end %>
                  </p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="trainers-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Name</th>
                        <th>Email</th>
                        <th>Specializations</th>
                        <th>Clients</th>
                        <th>Status</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for trainer <- @trainers do %>
                        <% assigned_members = Map.get(@trainer_member_map, trainer.id, []) %>
                        <% client_count = length(assigned_members) %>
                        <tr id={"trainer-#{trainer.id}"} class={if @expanded_trainer_id == trainer.id, do: "bg-base-300/20", else: ""}>
                          <td class="font-medium">{trainer.user.name}</td>
                          <td class="text-base-content/60">{trainer.user.email}</td>
                          <td>
                            <%= if trainer.specializations != [] do %>
                              <div class="flex flex-wrap gap-1">
                                <%= for spec <- trainer.specializations do %>
                                  <span class="badge badge-info badge-sm">{spec}</span>
                                <% end %>
                              </div>
                            <% else %>
                              <span class="text-base-content/40 text-sm">None listed</span>
                            <% end %>
                          </td>
                          <td>
                            <%= if client_count > 0 do %>
                              <button
                                phx-click="toggle_expand"
                                phx-value-id={trainer.id}
                                class="btn btn-ghost btn-xs gap-1"
                                id={"expand-clients-#{trainer.id}"}
                              >
                                <span class="badge badge-primary badge-sm">{client_count}</span>
                                <.icon
                                  name={if @expanded_trainer_id == trainer.id, do: "hero-chevron-up-mini", else: "hero-chevron-down-mini"}
                                  class="size-3"
                                />
                              </button>
                            <% else %>
                              <span class="text-base-content/30 text-sm">0</span>
                            <% end %>
                          </td>
                          <td>
                            <%= if trainer.is_active do %>
                              <span class="badge badge-success badge-sm">Active</span>
                            <% else %>
                              <span class="badge badge-error badge-sm">Inactive</span>
                            <% end %>
                          </td>
                          <td>
                            <button
                              phx-click="toggle_active"
                              phx-value-id={trainer.id}
                              class="btn btn-ghost btn-xs"
                              id={"toggle-trainer-#{trainer.id}"}
                            >
                              <%= if trainer.is_active do %>
                                <.icon name="hero-pause" class="size-4 text-warning" />
                              <% else %>
                                <.icon name="hero-play" class="size-4 text-success" />
                              <% end %>
                            </button>
                          </td>
                        </tr>
                        <%!-- Expanded client list --%>
                        <%= if @expanded_trainer_id == trainer.id and client_count > 0 do %>
                          <tr id={"trainer-clients-#{trainer.id}"}>
                            <td colspan="6" class="p-0">
                              <div class="bg-base-300/10 border-t border-base-300/30 px-6 py-3">
                                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
                                  Assigned Members ({client_count})
                                </p>
                                <div class="flex flex-wrap gap-2">
                                  <%= for member <- assigned_members do %>
                                    <div
                                      class="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-base-100 border border-base-300/50"
                                      id={"trainer-client-#{member.id}"}
                                    >
                                      <div class="w-6 h-6 rounded-full bg-primary/15 flex items-center justify-center">
                                        <span class="text-xs font-bold text-primary">
                                          {String.first(member.user.name || "M")}
                                        </span>
                                      </div>
                                      <div>
                                        <span class="text-sm font-medium">{member.user.name}</span>
                                        <span class="text-xs text-base-content/40 ml-1">{member.user.email}</span>
                                      </div>
                                    </div>
                                  <% end %>
                                </div>
                              </div>
                            </td>
                          </tr>
                        <% end %>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
