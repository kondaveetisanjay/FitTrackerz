defmodule FitconnexWeb.GymOperator.InvitationsLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case Fitconnex.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        member_invitations = case Fitconnex.Gym.list_pending_member_invitations(gym.id, actor: actor, load: [:invited_by]) do
          {:ok, invitations} -> invitations
          _ -> []
        end

        trainer_invitations = case Fitconnex.Gym.list_pending_trainer_invitations(gym.id, actor: actor, load: [:invited_by]) do
          {:ok, invitations} -> invitations
          _ -> []
        end

        {:ok,
         assign(socket,
           page_title: "Invitations",
           gym: gym,
           member_invitations: member_invitations,
           trainer_invitations: trainer_invitations
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Invitations",
           gym: nil,
           member_invitations: [],
           trainer_invitations: []
         )}
    end
  end

  defp status_badge_class(:pending), do: "badge-warning"
  defp status_badge_class(:accepted), do: "badge-success"
  defp status_badge_class(:rejected), do: "badge-error"
  defp status_badge_class(:expired), do: "badge-neutral"
  defp status_badge_class(_), do: "badge-neutral"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %I:%M %p")
  end

  defp format_date(_), do: "--"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Invitations</h1>
            <p class="text-base-content/50 mt-1">Track all member and trainer invitations.</p>
          </div>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before viewing invitations.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Member Invitations --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="member-invitations-card">
            <div class="card-body p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-user-group-solid" class="size-5 text-primary" />
                  Member Invitations
                  <span class="badge badge-neutral badge-sm">{length(@member_invitations)}</span>
                </h2>
                <a href="/gym/members" class="btn btn-ghost btn-xs gap-1">
                  <.icon name="hero-plus-mini" class="size-3" /> Invite
                </a>
              </div>
              <%= if @member_invitations == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                  <p class="text-sm text-base-content/50">No member invitations sent yet.</p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="member-invitations-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Email</th>
                        <th>Status</th>
                        <th>Invited By</th>
                        <th>Date</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for inv <- @member_invitations do %>
                        <tr id={"member-inv-#{inv.id}"}>
                          <td class="font-medium">{inv.invited_email}</td>
                          <td>
                            <span class={"badge badge-sm #{status_badge_class(inv.status)}"}>
                              {Phoenix.Naming.humanize(inv.status)}
                            </span>
                          </td>
                          <td class="text-base-content/60">{inv.invited_by.name}</td>
                          <td class="text-base-content/60 text-sm">{format_date(inv.inserted_at)}</td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Trainer Invitations --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="trainer-invitations-card">
            <div class="card-body p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-academic-cap-solid" class="size-5 text-secondary" />
                  Trainer Invitations
                  <span class="badge badge-neutral badge-sm">{length(@trainer_invitations)}</span>
                </h2>
                <a href="/gym/trainers" class="btn btn-ghost btn-xs gap-1">
                  <.icon name="hero-plus-mini" class="size-3" /> Invite
                </a>
              </div>
              <%= if @trainer_invitations == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                  <p class="text-sm text-base-content/50">No trainer invitations sent yet.</p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="trainer-invitations-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Email</th>
                        <th>Status</th>
                        <th>Invited By</th>
                        <th>Date</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for inv <- @trainer_invitations do %>
                        <tr id={"trainer-inv-#{inv.id}"}>
                          <td class="font-medium">{inv.invited_email}</td>
                          <td>
                            <span class={"badge badge-sm #{status_badge_class(inv.status)}"}>
                              {Phoenix.Naming.humanize(inv.status)}
                            </span>
                          </td>
                          <td class="text-base-content/60">{inv.invited_by.name}</td>
                          <td class="text-base-content/60 text-sm">{format_date(inv.inserted_at)}</td>
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
