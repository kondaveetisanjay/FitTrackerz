defmodule FitTrackerzWeb.Member.TrainerLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym, assigned_trainer: [:user]]) do
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
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="My Trainer" subtitle="Your assigned personal trainers." />

      <%= if @memberships == [] do %>
        <.empty_state
          icon="hero-academic-cap"
          title="No Gym Membership"
          subtitle="Join a gym first to get assigned a trainer."
        />
      <% else %>
        <div class="space-y-6">
          <%= for membership <- @memberships do %>
            <.card id={"trainer-#{membership.id}"}>
              <%!-- Gym context --%>
              <div class="flex items-center gap-2 text-sm text-base-content/50 mb-4">
                <.icon name="hero-building-office-2-mini" class="size-4" />
                <span>{membership.gym.name}</span>
              </div>

              <%= if membership.assigned_trainer do %>
                <div class="flex items-start gap-5">
                  <.avatar name={membership.assigned_trainer.user.name} size="lg" />
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
                          <.badge variant="neutral" size="sm">{Phoenix.Naming.humanize(spec)}</.badge>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <.empty_state
                  icon="hero-academic-cap"
                  title="No Trainer Assigned"
                  subtitle="Your gym operator will assign a trainer to you."
                />
              <% end %>
            </.card>
          <% end %>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
