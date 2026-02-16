defmodule FitconnexWeb.GymOperator.TrainersLive do
  use FitconnexWeb, :live_view

  alias FitconnexWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case Fitconnex.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        trainers = case Fitconnex.Gym.list_trainers_by_gym(gym.id, actor: actor, load: [:user]) do
          {:ok, trainers} -> trainers
          _ -> []
        end

        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:ok,
         assign(socket,
           page_title: "Trainers",
           gym: gym,
           trainers: trainers,
           invite_form: invite_form,
           show_invite: false
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Trainers",
           gym: nil,
           trainers: [],
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
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    case Fitconnex.Gym.create_trainer_invitation(%{
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

    trainer = Enum.find(socket.assigns.trainers, &(&1.id == id))

    if trainer do
      case Fitconnex.Gym.update_gym_trainer(trainer, %{is_active: !trainer.is_active}, actor: actor) do
        {:ok, _updated} ->
          trainers = case Fitconnex.Gym.list_trainers_by_gym(gym.id, actor: actor, load: [:user]) do
            {:ok, trainers} -> trainers
            _ -> []
          end

          {:noreply,
           socket
           |> put_flash(:info, "Trainer status updated.")
           |> assign(trainers: trainers)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update trainer status.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Trainer not found.")}
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
                    No trainers yet. Invite trainers to build your team!
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
                        <th>Status</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for trainer <- @trainers do %>
                        <tr id={"trainer-#{trainer.id}"}>
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
