defmodule FitTrackerzWeb.Trainer.GymsLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case FitTrackerz.Gym.list_active_trainerships(actor.id, actor: actor, load: [gym: [:branches]]) do
      {:ok, trainers} -> trainers
      _ -> []
    end

    gyms = Enum.map(gym_trainers, & &1.gym)

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
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="My Gyms" subtitle="Gyms you are associated with as a trainer." />

      <%= if @gyms == [] do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Association"
          subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you as a trainer."
        />
      <% else %>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for gym <- @gyms do %>
            <.link
              navigate={"/trainer/gyms/#{gym.id}"}
              class="block"
              id={"gym-#{gym.id}"}
            >
              <.card>
                <div class="flex items-start justify-between gap-3">
                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                    <.icon name="hero-building-office-2-solid" class="size-6 text-primary" />
                  </div>
                  <%= if gym.status == :verified do %>
                    <.badge variant="success">Verified</.badge>
                  <% else %>
                    <.badge variant="warning">{Phoenix.Naming.humanize(gym.status)}</.badge>
                  <% end %>
                </div>
                <h3 class="text-lg font-bold mt-3">{gym.name}</h3>
                <div class="flex items-center gap-2 mt-1 text-sm text-base-content/50">
                  <.icon name="hero-map-pin-mini" class="size-4" />
                  <span>{primary_city(gym.branches)}</span>
                </div>
                <div class="flex items-center gap-2 mt-2 text-sm text-base-content/50">
                  <.icon name="hero-building-office-mini" class="size-4" />
                  <span>1 location</span>
                </div>
                <div class="mt-3 text-xs text-primary font-semibold flex items-center gap-1">
                  View Details <.icon name="hero-arrow-right-mini" class="size-3" />
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
