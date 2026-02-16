defmodule FitconnexWeb.GymOperator.MembersLive do
  use FitconnexWeb, :live_view

  alias FitconnexWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case Fitconnex.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        members = case Fitconnex.Gym.list_members_by_gym(gym.id, actor: actor, load: [:user, assigned_trainer: [:user]]) do
          {:ok, members} -> members
          _ -> []
        end

        trainers = case Fitconnex.Gym.list_active_trainers_by_gym(gym.id, actor: actor, load: [:user]) do
          {:ok, trainers} -> trainers
          _ -> []
        end

        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:ok,
         assign(socket,
           page_title: "Members",
           gym: gym,
           members: members,
           trainers: trainers,
           invite_form: invite_form,
           show_invite: false,
           assign_member_id: nil
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Members",
           gym: nil,
           members: [],
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
    actor = socket.assigns.current_user
    gym = socket.assigns.gym
    email = params["email"]

    case Fitconnex.Gym.create_member_invitation(%{
      invited_email: email,
      gym_id: gym.id,
      invited_by_id: actor.id
    }, actor: actor) do
      {:ok, _invitation} ->
        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}!")
         |> assign(invite_form: invite_form, show_invite: false)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("show_assign_trainer", %{"member-id" => member_id}, socket) do
    {:noreply, assign(socket, assign_member_id: member_id)}
  end

  def handle_event("cancel_assign_trainer", _params, socket) do
    {:noreply, assign(socket, assign_member_id: nil)}
  end

  def handle_event("assign_trainer", %{"trainer_id" => trainer_id, "member_id" => member_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    if trainer_id == "" do
      {:noreply, put_flash(socket, :error, "Please select a trainer.")}
    else
      case Fitconnex.Gym.create_assignment_request(%{
        gym_id: gym.id,
        member_id: member_id,
        trainer_id: trainer_id,
        requested_by_id: actor.id
      }, actor: actor) do
        {:ok, _request} ->
          {:noreply,
           socket
           |> put_flash(:info, "Client assignment request sent to trainer!")
           |> assign(assign_member_id: nil)}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    case Fitconnex.Gym.get_gym_member(id, actor: actor) do
      {:ok, member} ->
        case Fitconnex.Gym.update_gym_member(member, %{is_active: !member.is_active}, actor: actor) do
          {:ok, _updated} ->
            members = case Fitconnex.Gym.list_members_by_gym(gym.id, actor: actor, load: [:user, assigned_trainer: [:user]]) do
              {:ok, members} -> members
              _ -> []
            end

            {:noreply,
             socket
             |> put_flash(:info, "Member status updated.")
             |> assign(members: members)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update member status.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Member not found.")}
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
