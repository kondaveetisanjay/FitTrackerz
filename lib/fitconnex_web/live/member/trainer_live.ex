defmodule FitconnexWeb.Member.TrainerLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case Fitconnex.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym, assigned_trainer: [:user]]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    {:ok,
     assign(socket,
       page_title: "My Trainer",
       memberships: memberships
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl sm:text-3xl font-black tracking-tight">My Trainer</h1>
          <p class="text-base-content/50 mt-1">Your assigned personal trainers.</p>
        </div>

        <%= if @memberships == [] do %>
          <div class="min-h-[40vh] flex items-center justify-center">
            <div class="text-center max-w-md">
              <div class="w-20 h-20 rounded-3xl bg-warning/10 flex items-center justify-center mx-auto mb-6">
                <.icon name="hero-academic-cap-solid" class="size-10 text-warning" />
              </div>

              <h2 class="text-xl font-black tracking-tight">No Gym Membership</h2>

              <p class="text-base-content/50 mt-3">
                Join a gym first to get assigned a trainer.
              </p>
            </div>
          </div>
        <% else %>
          <div class="space-y-6">
            <%= for membership <- @memberships do %>
              <div
                class="card bg-base-200/50 border border-base-300/50"
                id={"trainer-#{membership.id}"}
              >
                <div class="card-body p-6">
                  <%!-- Gym context --%>
                  <div class="flex items-center gap-2 text-sm text-base-content/50 mb-4">
                    <.icon name="hero-building-office-2-mini" class="size-4" />
                    <span>{membership.gym.name}</span>
                  </div>

                  <%= if membership.assigned_trainer do %>
                    <div class="flex items-start gap-4">
                      <div class="w-16 h-16 rounded-2xl bg-secondary/10 flex items-center justify-center shrink-0">
                        <.icon name="hero-academic-cap-solid" class="size-8 text-secondary" />
                      </div>

                      <div class="flex-1">
                        <h2 class="text-xl font-bold">
                          {membership.assigned_trainer.user.name}
                        </h2>

                        <p class="text-sm text-base-content/60 mt-1">
                          {membership.assigned_trainer.user.email}
                        </p>

                        <%= if membership.assigned_trainer.specializations != [] do %>
                          <div class="flex flex-wrap gap-1.5 mt-3">
                            <%= for spec <- membership.assigned_trainer.specializations do %>
                              <span class="badge badge-outline badge-sm">
                                {Phoenix.Naming.humanize(spec)}
                              </span>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% else %>
                    <div class="p-6 rounded-xl bg-base-300/30 text-center">
                      <div class="w-16 h-16 rounded-2xl bg-secondary/10 flex items-center justify-center mx-auto mb-4">
                        <.icon name="hero-academic-cap" class="size-8 text-secondary" />
                      </div>

                      <p class="font-semibold">No Trainer Assigned</p>

                      <p class="text-sm text-base-content/50 mt-1">
                        Your gym operator will assign a trainer to you.
                      </p>
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
