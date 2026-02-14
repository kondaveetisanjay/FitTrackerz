defmodule FitconnexWeb.Trainer.GymsLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    gym_trainers =
      Fitconnex.Gym.GymTrainer
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.filter(is_active == true)
      |> Ash.Query.load(gym: [:branches])
      |> Ash.read!()

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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl sm:text-3xl font-black tracking-tight">My Gyms</h1>
          <p class="text-base-content/50 mt-1">Gyms you are associated with as a trainer.</p>
        </div>

        <%= if @gyms == [] do %>
          <div class="min-h-[40vh] flex items-center justify-center">
            <div class="text-center max-w-md">
              <div class="w-20 h-20 rounded-3xl bg-warning/10 flex items-center justify-center mx-auto mb-6">
                <.icon name="hero-building-office-2-solid" class="size-10 text-warning" />
              </div>

              <h2 class="text-xl font-black tracking-tight">No Gym Association</h2>

              <p class="text-base-content/50 mt-3">
                You haven't been added to any gym yet. Ask a gym operator to invite you as a trainer.
              </p>
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for gym <- @gyms do %>
              <.link
                navigate={"/trainer/gyms/#{gym.id}"}
                class="card bg-base-200/50 border border-base-300/50 hover:shadow-lg hover:border-primary/30 transition-all"
                id={"gym-#{gym.id}"}
              >
                <div class="card-body p-5">
                  <div class="flex items-start justify-between gap-3">
                    <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                      <.icon name="hero-building-office-2-solid" class="size-6 text-primary" />
                    </div>

                    <%= if gym.status == :verified do %>
                      <span class="badge badge-success badge-sm gap-1">
                        <.icon name="hero-check-badge-mini" class="size-3" /> Verified
                      </span>
                    <% else %>
                      <span class="badge badge-warning badge-sm gap-1">
                        {Phoenix.Naming.humanize(gym.status)}
                      </span>
                    <% end %>
                  </div>

                  <h3 class="text-lg font-bold mt-3">{gym.name}</h3>

                  <div class="flex items-center gap-2 mt-1 text-sm text-base-content/50">
                    <.icon name="hero-map-pin-mini" class="size-4" />
                    <span>{primary_city(gym.branches)}</span>
                  </div>

                  <div class="flex items-center gap-2 mt-2 text-sm text-base-content/50">
                    <.icon name="hero-building-office-mini" class="size-4" />
                    <span>{length(gym.branches)} {if length(gym.branches) == 1, do: "branch", else: "branches"}</span>
                  </div>

                  <div class="mt-3 text-xs text-primary font-semibold flex items-center gap-1">
                    View Details <.icon name="hero-arrow-right-mini" class="size-3" />
                  </div>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
