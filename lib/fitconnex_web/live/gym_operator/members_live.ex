defmodule FitconnexWeb.GymOperator.MembersLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    case find_gym(user.id) do
      {:ok, gym} ->
        gid = gym.id

        members =
          Fitconnex.Gym.GymMember
          |> Ash.Query.filter(gym_id == ^gid)
          |> Ash.Query.load([:user, assigned_trainer: [:user]])
          |> Ash.read!()

        branches =
          Fitconnex.Gym.GymBranch
          |> Ash.Query.filter(gym_id == ^gid)
          |> Ash.read!()

        trainers =
          Fitconnex.Gym.GymTrainer
          |> Ash.Query.filter(gym_id == ^gid)
          |> Ash.Query.filter(is_active == true)
          |> Ash.Query.load([:user])
          |> Ash.read!()

        invite_form = to_form(%{"email" => "", "branch_id" => ""}, as: "invite")

        {:ok,
         assign(socket,
           page_title: "Members",
           gym: gym,
           members: members,
           branches: branches,
           trainers: trainers,
           invite_form: invite_form,
           show_invite: false,
           assign_member_id: nil
         )}

      :no_gym ->
        {:ok,
         assign(socket,
           page_title: "Members",
           gym: nil,
           members: [],
           branches: [],
           trainers: [],
           invite_form: nil,
           show_invite: false,
           assign_member_id: nil
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

  def handle_event("invite", %{"invite" => params}, socket) do
    user = socket.assigns.current_user
    gym = socket.assigns.gym
    email = params["email"]
    branch_id = params["branch_id"]

    create_params = %{
      invited_email: email,
      gym_id: gym.id,
      invited_by_id: user.id
    }

    create_params =
      if branch_id && branch_id != "",
        do: Map.put(create_params, :branch_id, branch_id),
        else: create_params

    case Fitconnex.Gym.MemberInvitation
         |> Ash.Changeset.for_create(:create, create_params)
         |> Ash.create() do
      {:ok, _invitation} ->
        invite_form = to_form(%{"email" => "", "branch_id" => ""}, as: "invite")

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}!")
         |> assign(invite_form: invite_form, show_invite: false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation. Please try again.")}
    end
  end

  def handle_event("show_assign_trainer", %{"member-id" => member_id}, socket) do
    {:noreply, assign(socket, assign_member_id: member_id)}
  end

  def handle_event("cancel_assign_trainer", _params, socket) do
    {:noreply, assign(socket, assign_member_id: nil)}
  end

  def handle_event("assign_trainer", %{"trainer_id" => trainer_id, "member_id" => member_id}, socket) do
    user = socket.assigns.current_user
    gym = socket.assigns.gym

    if trainer_id == "" do
      {:noreply, put_flash(socket, :error, "Please select a trainer.")}
    else
      case Fitconnex.Gym.ClientAssignmentRequest
           |> Ash.Changeset.for_create(:create, %{
             gym_id: gym.id,
             member_id: member_id,
             trainer_id: trainer_id,
             requested_by_id: user.id
           })
           |> Ash.create() do
        {:ok, _request} ->
          {:noreply,
           socket
           |> put_flash(:info, "Client assignment request sent to trainer!")
           |> assign(assign_member_id: nil)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send assignment request. Please try again.")}
      end
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    gym = socket.assigns.gym
    gid = gym.id

    member =
      Fitconnex.Gym.GymMember
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.filter(gym_id == ^gid)
      |> Ash.read!()
      |> List.first()

    if member do
      case member
           |> Ash.Changeset.for_update(:update, %{is_active: !member.is_active})
           |> Ash.update() do
        {:ok, _updated} ->
          members =
            Fitconnex.Gym.GymMember
            |> Ash.Query.filter(gym_id == ^gid)
            |> Ash.Query.load([:user, assigned_trainer: [:user]])
            |> Ash.read!()

          {:noreply,
           socket
           |> put_flash(:info, "Member status updated.")
           |> assign(members: members)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update member status.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Member not found.")}
    end
  end

  defp find_gym(user_id) do
    case Fitconnex.Gym.Gym
         |> Ash.Query.filter(owner_id == ^user_id)
         |> Ash.read!() do
      [gym | _] -> {:ok, gym}
      [] -> :no_gym
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Members</h1>
              <p class="text-base-content/50 mt-1">Manage gym memberships and invite new members.</p>
            </div>
          </div>
          <%= if @gym do %>
            <button
              phx-click="toggle_invite"
              class="btn btn-primary btn-sm gap-2 font-semibold"
              id="toggle-invite-btn"
            >
              <.icon name="hero-user-plus-mini" class="size-4" /> Invite Member
            </button>
          <% end %>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before managing members.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Invite Form --%>
          <%= if @show_invite do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="invite-member-card">
              <div class="card-body p-6">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-envelope-solid" class="size-5 text-primary" /> Invite New Member
                </h2>
                <.form
                  for={@invite_form}
                  id="invite-member-form"
                  phx-change="validate_invite"
                  phx-submit="invite"
                >
                  <div class="flex flex-col sm:flex-row gap-4 items-end">
                    <div class="flex-1">
                      <.input
                        field={@invite_form[:email]}
                        type="email"
                        label="Email Address"
                        placeholder="member@example.com"
                        required
                      />
                    </div>

                    <div class="flex-1">
                      <label class="label" for="invite_branch_id">
                        <span class="label-text">Branch</span>
                      </label>

                      <select
                        name="invite[branch_id]"
                        id="invite_branch_id"
                        class="select select-bordered w-full select-sm"
                      >
                        <option value="">Select a branch</option>

                        <%= for branch <- @branches do %>
                          <option value={branch.id}>
                            {branch.city}, {branch.state} — {branch.address}
                            {if branch.is_primary, do: " (Primary)", else: ""}
                          </option>
                        <% end %>
                      </select>
                    </div>

                    <div class="mb-2">
                      <button type="submit" class="btn btn-primary btn-sm gap-2" id="send-invite-btn">
                        <.icon name="hero-paper-airplane" class="size-4" /> Send Invite
                      </button>
                    </div>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Members Table --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="members-table-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-user-group-solid" class="size-5 text-primary" /> All Members
                <span class="badge badge-neutral badge-sm">{length(@members)}</span>
              </h2>
              <%= if @members == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                  <p class="text-sm text-base-content/50">
                    No members yet. Send invitations to grow your gym!
                  </p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="members-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Name</th>
                        <th>Email</th>
                        <th>Assigned Trainer</th>
                        <th>Status</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for member <- @members do %>
                        <tr id={"member-#{member.id}"}>
                          <td class="font-medium">{member.user.name}</td>
                          <td class="text-base-content/60">{member.user.email}</td>
                          <td>
                            <%= if member.assigned_trainer do %>
                              <span class="badge badge-info badge-sm">
                                {member.assigned_trainer.user.name}
                              </span>
                            <% else %>
                              <span class="text-base-content/40 text-sm">Unassigned</span>
                            <% end %>
                          </td>
                          <td>
                            <%= if member.is_active do %>
                              <span class="badge badge-success badge-sm">Active</span>
                            <% else %>
                              <span class="badge badge-error badge-sm">Inactive</span>
                            <% end %>
                          </td>
                          <td>
                            <div class="flex items-center gap-1">
                              <button
                                phx-click="toggle_active"
                                phx-value-id={member.id}
                                class="btn btn-ghost btn-xs"
                                id={"toggle-member-#{member.id}"}
                              >
                                <%= if member.is_active do %>
                                  <.icon name="hero-pause" class="size-4 text-warning" />
                                <% else %>
                                  <.icon name="hero-play" class="size-4 text-success" />
                                <% end %>
                              </button>
                              <button
                                phx-click="show_assign_trainer"
                                phx-value-member-id={member.id}
                                class="btn btn-ghost btn-xs"
                                id={"assign-trainer-btn-#{member.id}"}
                                title="Assign Trainer"
                              >
                                <.icon name="hero-academic-cap" class="size-4 text-info" />
                              </button>
                            </div>
                            <%= if @assign_member_id == member.id do %>
                              <div class="mt-2 p-3 rounded-lg bg-base-300/30 border border-base-300/50">
                                <form phx-submit="assign_trainer" class="flex flex-col gap-2">
                                  <input type="hidden" name="member_id" value={member.id} />
                                  <select
                                    name="trainer_id"
                                    class="select select-bordered select-xs w-full"
                                  >
                                    <option value="">Select a trainer</option>
                                    <%= for trainer <- @trainers do %>
                                      <option value={trainer.id}>
                                        {trainer.user.name}
                                      </option>
                                    <% end %>
                                  </select>
                                  <div class="flex gap-1">
                                    <button type="submit" class="btn btn-primary btn-xs gap-1">
                                      <.icon name="hero-paper-airplane" class="size-3" /> Send
                                    </button>
                                    <button
                                      type="button"
                                      phx-click="cancel_assign_trainer"
                                      class="btn btn-ghost btn-xs"
                                    >
                                      Cancel
                                    </button>
                                  </div>
                                </form>
                              </div>
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
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
