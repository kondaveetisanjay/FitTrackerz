defmodule FitTrackerzWeb.Member.GymLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [gym: [:branches]]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    gyms = Enum.map(memberships, & &1.gym) |> Enum.uniq_by(& &1.id)

    {:ok,
     assign(socket,
       page_title: "My Gyms",
       gyms: gyms
     )}
  end

  defp primary_city(branches) do
    case Enum.find(branches, & &1.is_primary) || List.first(branches) do
      nil -> "No branches"
      branch -> "#{branch.city}, #{branch.state}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="My Gyms" subtitle="Gyms you are a member of." />

      <%= if @gyms == [] do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You haven't joined any gym yet. Ask a gym operator to invite you as a member."
        />
      <% else %>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
          <%= for gym <- @gyms do %>
            <.link
              navigate={"/member/gym/#{gym.id}"}
              class="group"
              id={"gym-#{gym.id}"}
            >
              <.card>
                <div class="space-y-4">
                  <div class="flex items-start justify-between gap-3">
                    <.avatar name={gym.name} size="lg" />
                    <%= if gym.status == :verified do %>
                      <.badge variant="success">Verified</.badge>
                    <% else %>
                      <.badge variant="warning">{Phoenix.Naming.humanize(gym.status)}</.badge>
                    <% end %>
                  </div>

                  <div>
                    <h3 class="text-lg font-bold group-hover:text-primary transition-colors">{gym.name}</h3>
                    <div class="flex items-center gap-2 mt-2 text-sm text-base-content/50">
                      <.icon name="hero-map-pin-mini" class="size-4" />
                      <span>{primary_city(gym.branches)}</span>
                    </div>
                  </div>

                  <div class="text-sm text-primary font-semibold flex items-center gap-1">
                    View Details <.icon name="hero-arrow-right-mini" class="size-4" />
                  </div>
                </div>
              </.card>
            </.link>
          <% end %>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
