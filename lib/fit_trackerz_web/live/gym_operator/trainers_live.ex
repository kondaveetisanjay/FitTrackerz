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

  # -- Helpers --

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
      <div class="space-y-6">
        <.page_header title="Trainers" subtitle="Manage your gym trainers and invite new ones." back_path="/gym">
          <:actions>
            <%= if @gym do %>
              <.button variant="primary" size="sm" icon="hero-academic-cap-mini" phx-click="toggle_invite" id="toggle-trainer-invite-btn">Invite Trainer</.button>
            <% end %>
          </:actions>
        </.page_header>

        <%= if @gym == nil do %>
          <.empty_state icon="hero-building-office-solid" title="No Gym Found" subtitle="You need to create a gym first before managing trainers.">
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus-mini" navigate="/gym/setup">Setup Gym</.button>
            </:action>
          </.empty_state>
        <% else %>
          <%!-- Invite Form --%>
          <%= if @show_invite do %>
            <.card title="Invite New Trainer" id="invite-trainer-card">
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
                    />
                  </div>
                  <div class="mb-2">
                    <.button variant="primary" size="sm" icon="hero-paper-airplane" type="submit" id="send-trainer-invite-btn">Send Invite</.button>
                  </div>
                </div>
              </.form>
            </.card>
          <% end %>

          <%!-- Search & Filter --%>
          <.filter_bar search_placeholder="Search by name, email, or specialization..." search_value={@search} on_search="search">
            <:filter>
              <div class="flex gap-2">
                <.button
                  variant={if(@filter_status == "all", do: "primary", else: "ghost")}
                  size="sm"
                  phx-click="filter_status"
                  phx-value-status="all"
                >
                  All <.badge variant="neutral" size="sm">{length(@all_trainers)}</.badge>
                </.button>
                <.button
                  variant={if(@filter_status == "active", do: "primary", else: "ghost")}
                  size="sm"
                  phx-click="filter_status"
                  phx-value-status="active"
                >
                  Active
                </.button>
                <.button
                  variant={if(@filter_status == "inactive", do: "primary", else: "ghost")}
                  size="sm"
                  phx-click="filter_status"
                  phx-value-status="inactive"
                >
                  Inactive
                </.button>
              </div>
            </:filter>
          </.filter_bar>

          <%!-- Trainers Table --%>
          <.card title="All Trainers" subtitle={"#{length(@trainers)} trainers"}>
            <%= if @trainers == [] do %>
              <.empty_state
                icon="hero-academic-cap"
                title={if @search != "" or @filter_status != "all", do: "No trainers match your filters", else: "No trainers yet"}
                subtitle={if @search != "" or @filter_status != "all", do: "Try adjusting your search or filters.", else: "Invite trainers to build your team!"}
              />
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
                        <td>
                          <div class="flex items-center gap-2">
                            <.avatar name={trainer.user.name || "T"} size="sm" />
                            <span class="font-medium">{trainer.user.name}</span>
                          </div>
                        </td>
                        <td class="text-base-content/60">{trainer.user.email}</td>
                        <td>
                          <%= if trainer.specializations != [] do %>
                            <div class="flex flex-wrap gap-1">
                              <%= for spec <- trainer.specializations do %>
                                <.badge variant="info" size="sm">{spec}</.badge>
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
                              <.badge variant="primary" size="sm">{client_count}</.badge>
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
                            <.badge variant="success" size="sm">Active</.badge>
                          <% else %>
                            <.badge variant="error" size="sm">Inactive</.badge>
                          <% end %>
                        </td>
                        <td>
                          <.button
                            variant="ghost"
                            size="sm"
                            phx-click="toggle_active"
                            phx-value-id={trainer.id}
                            id={"toggle-trainer-#{trainer.id}"}
                          >
                            <%= if trainer.is_active do %>
                              <.icon name="hero-pause" class="size-4 text-warning" />
                            <% else %>
                              <.icon name="hero-play" class="size-4 text-success" />
                            <% end %>
                          </.button>
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
                                    <.avatar name={member.user.name || "M"} size="sm" />
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
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
