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
          |> Ash.Query.load([:user, :assigned_trainer])
          |> Ash.read!()

        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:ok,
         assign(socket,
           page_title: "Members",
           gym: gym,
           members: members,
           invite_form: invite_form,
           show_invite: false
         )}

      :no_gym ->
        {:ok,
         assign(socket,
           page_title: "Members",
           gym: nil,
           members: [],
           invite_form: nil,
           show_invite: false
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
    user = socket.assigns.current_user
    gym = socket.assigns.gym

    case Fitconnex.Gym.MemberInvitation
         |> Ash.Changeset.for_create(:create, %{
           invited_email: email,
           gym_id: gym.id,
           invited_by_id: user.id
         })
         |> Ash.create() do
      {:ok, _invitation} ->
        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}!")
         |> assign(invite_form: invite_form, show_invite: false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation. Please try again.")}
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
            |> Ash.Query.load([:user, :assigned_trainer])
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
                  <div class="flex gap-4 items-end">
                    <div class="flex-1">
                      <.input
                        field={@invite_form[:email]}
                        type="email"
                        label="Email Address"
                        placeholder="member@example.com"
                        required
                      />
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
                                {member.assigned_trainer.name}
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
