defmodule FitconnexWeb.Member.GymLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    memberships =
      Fitconnex.Gym.GymMember
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.filter(is_active == true)
      |> Ash.Query.load([:branch, gym: [:branches]])
      |> Ash.read!()

    {:ok,
     assign(socket,
       page_title: "My Gym",
       memberships: memberships
     )}
  end

  defp maps_url(lat, lng) when is_number(lat) and is_number(lng) do
    "https://www.google.com/maps?q=#{lat},#{lng}"
  end

  defp maps_url(_, _), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl sm:text-3xl font-black tracking-tight">My Gym</h1>
          <p class="text-base-content/50 mt-1">Gyms you are a member of.</p>
        </div>

        <%= if @memberships == [] do %>
          <div class="min-h-[40vh] flex items-center justify-center">
            <div class="text-center max-w-md">
              <div class="w-20 h-20 rounded-3xl bg-warning/10 flex items-center justify-center mx-auto mb-6">
                <.icon name="hero-building-office-2-solid" class="size-10 text-warning" />
              </div>

              <h2 class="text-xl font-black tracking-tight">No Gym Membership</h2>

              <p class="text-base-content/50 mt-3">
                You haven't joined any gym yet. Ask a gym operator to invite you as a member.
              </p>
            </div>
          </div>
        <% else %>
          <div class="space-y-6">
            <%= for membership <- @memberships do %>
              <div
                class="card bg-base-200/50 border border-base-300/50"
                id={"gym-#{membership.gym.id}"}
              >
                <div class="card-body p-6">
                  <%!-- Gym Header --%>
                  <div class="flex items-start justify-between gap-4">
                    <div class="flex items-center gap-4">
                      <div class="w-14 h-14 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                        <.icon name="hero-building-office-2-solid" class="size-7 text-primary" />
                      </div>

                      <div>
                        <h2 class="text-xl font-bold">{membership.gym.name}</h2>

                        <div class="flex items-center gap-2 mt-1">
                          <%= if membership.gym.status == :verified do %>
                            <span class="badge badge-success badge-sm gap-1">
                              <.icon name="hero-check-badge-mini" class="size-3" /> Verified
                            </span>
                          <% else %>
                            <span class="badge badge-warning badge-sm">
                              {Phoenix.Naming.humanize(membership.gym.status)}
                            </span>
                          <% end %>

                          <span class="badge badge-neutral badge-sm">
                            {length(membership.gym.branches)} {if length(membership.gym.branches) == 1, do: "branch", else: "branches"}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <%!-- About --%>
                  <%= if membership.gym.description do %>
                    <div class="mt-4">
                      <p class="text-base-content/70 whitespace-pre-wrap">
                        {membership.gym.description}
                      </p>
                    </div>
                  <% end %>

                  <%!-- Assigned Branch --%>
                  <%= if membership.branch do %>
                    <div class="mt-5">
                      <h3 class="text-sm font-semibold text-base-content/40 uppercase tracking-wider mb-3">
                        Your Branch
                      </h3>

                      <div class="flex items-start gap-4 p-4 rounded-xl bg-primary/5 border border-primary/20">
                        <%= if membership.branch.logo_url do %>
                          <img
                            src={membership.branch.logo_url}
                            class="w-14 h-14 rounded-lg object-cover shrink-0"
                          />
                        <% end %>

                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2">
                            <p class="font-semibold">
                              {membership.branch.city}, {membership.branch.state}
                            </p>

                            <%= if membership.branch.is_primary do %>
                              <span class="badge badge-xs badge-primary">Primary</span>
                            <% end %>
                          </div>

                          <p class="text-sm text-base-content/60 mt-0.5">
                            {membership.branch.address} — {membership.branch.postal_code}
                          </p>
                        </div>

                        <%= if maps_url(membership.branch.latitude, membership.branch.longitude) do %>
                          <a
                            href={maps_url(membership.branch.latitude, membership.branch.longitude)}
                            target="_blank"
                            rel="noopener noreferrer"
                            class="btn btn-outline btn-xs gap-1 shrink-0 self-center"
                          >
                            <.icon name="hero-map-pin-mini" class="size-3" /> Map
                          </a>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%!-- All Branches --%>
                  <%= if membership.gym.branches != [] do %>
                    <div class="mt-5">
                      <h3 class="text-sm font-semibold text-base-content/40 uppercase tracking-wider mb-3">
                        All Locations
                      </h3>

                      <div class="space-y-2">
                        <%= for branch <- membership.gym.branches do %>
                          <div class="flex items-start gap-3 p-3 rounded-lg bg-base-300/20">
                            <%= if branch.logo_url do %>
                              <img
                                src={branch.logo_url}
                                class="w-10 h-10 rounded-lg object-cover shrink-0"
                              />
                            <% end %>

                            <div class="flex-1 min-w-0">
                              <div class="flex items-center gap-2">
                                <p class="font-medium text-sm">
                                  {branch.city}, {branch.state}
                                </p>

                                <%= if branch.is_primary do %>
                                  <span class="badge badge-xs badge-primary">Primary</span>
                                <% end %>
                              </div>

                              <p class="text-xs text-base-content/50 mt-0.5">
                                {branch.address} — {branch.postal_code}
                              </p>
                            </div>

                            <%= if maps_url(branch.latitude, branch.longitude) do %>
                              <a
                                href={maps_url(branch.latitude, branch.longitude)}
                                target="_blank"
                                rel="noopener noreferrer"
                                class="btn btn-ghost btn-xs gap-1 shrink-0 self-center"
                              >
                                <.icon name="hero-map-pin-mini" class="size-3" /> Map
                              </a>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
