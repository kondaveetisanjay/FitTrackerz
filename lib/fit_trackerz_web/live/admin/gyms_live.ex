defmodule FitTrackerzWeb.Admin.GymsLive do
  use FitTrackerzWeb, :live_view

  @status_badge_classes %{
    pending_verification: "badge-warning",
    verified: "badge-success",
    suspended: "badge-error"
  }

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gyms =
      case FitTrackerz.Gym.list_gyms(actor: actor, load: [:owner, :branches, :gym_members]) do
        {:ok, gyms} -> gyms
        _ -> []
      end

    {:ok,
     assign(socket,
       page_title: "Manage Gyms",
       gyms: gyms
     )}
  end

  @impl true
  def handle_event("verify_gym", %{"id" => gym_id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_gym(gym_id, actor: actor) do
      {:ok, gym} ->
        case FitTrackerz.Gym.update_gym(gym, %{status: :verified}, actor: actor) do
          {:ok, _} -> {:noreply, reload_gyms(socket)}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to verify gym.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Gym not found.")}
    end
  end

  @impl true
  def handle_event("suspend_gym", %{"id" => gym_id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_gym(gym_id, actor: actor) do
      {:ok, gym} ->
        case FitTrackerz.Gym.update_gym(gym, %{status: :suspended}, actor: actor) do
          {:ok, _} -> {:noreply, reload_gyms(socket)}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to suspend gym.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Gym not found.")}
    end
  end

  @impl true
  def handle_event("toggle_promoted", %{"id" => gym_id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_gym(gym_id, actor: actor) do
      {:ok, gym} ->
        case FitTrackerz.Gym.update_gym(gym, %{is_promoted: !gym.is_promoted}, actor: actor) do
          {:ok, _} -> {:noreply, reload_gyms(socket)}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to update promotion status.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Gym not found.")}
    end
  end

  defp reload_gyms(socket) do
    actor = socket.assigns.current_user

    gyms =
      case FitTrackerz.Gym.list_gyms(actor: actor, load: [:owner, :branches, :gym_members]) do
        {:ok, gyms} -> gyms
        _ -> []
      end

    assign(socket, gyms: gyms)
  end

  defp status_badge_class(status) do
    Map.get(@status_badge_classes, status, "badge-ghost")
  end

  defp format_status(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp owner_name(%{owner: %{name: name}}), do: name
  defp owner_name(_), do: "Unknown"

  defp count_loaded(assoc) when is_list(assoc), do: length(assoc)
  defp count_loaded(_), do: 0

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex items-center justify-between" id="gyms-header">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">Gyms</h1>
              <p class="text-base-content/50 mt-1">
                {length(@gyms)} total gyms on the platform
              </p>
            </div>
          </div>
          <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center">
            <.icon name="hero-building-office-2-solid" class="size-6 text-secondary" />
          </div>
        </div>

        <%!-- Gyms Grid --%>
        <%= if Enum.empty?(@gyms) do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="gyms-empty-state">
            <div class="card-body flex flex-col items-center justify-center py-16 px-4">
              <div class="w-16 h-16 rounded-2xl bg-base-300/50 flex items-center justify-center mb-4">
                <.icon name="hero-building-office-2" class="size-8 text-base-content/30" />
              </div>
              <p class="text-lg font-semibold text-base-content/50">No gyms found</p>
              <p class="text-sm text-base-content/30 mt-1">
                Gyms will appear here once operators create them.
              </p>
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6" id="gyms-grid">
            <div
              :for={gym <- @gyms}
              class="card bg-base-200/50 border border-base-300/50"
              id={"gym-card-#{gym.id}"}
            >
              <div class="card-body p-5 space-y-4">
                <%!-- Gym Name & Status --%>
                <div class="flex items-start justify-between">
                  <div class="min-w-0">
                    <h2 class="text-lg font-bold truncate" id={"gym-name-#{gym.id}"}>{gym.name}</h2>
                    <p class="text-xs text-base-content/40 font-mono mt-0.5" id={"gym-slug-#{gym.id}"}>
                      {gym.slug}
                    </p>
                  </div>
                  <span
                    class={"badge badge-sm #{status_badge_class(gym.status)} shrink-0"}
                    id={"gym-status-#{gym.id}"}
                  >
                    {format_status(gym.status)}
                  </span>
                </div>

                <%!-- Owner --%>
                <div class="flex items-center gap-2">
                  <div class="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-user-solid" class="size-3.5 text-primary" />
                  </div>
                  <div>
                    <p class="text-xs text-base-content/40">Owner</p>
                    <p class="text-sm font-semibold" id={"gym-owner-#{gym.id}"}>{owner_name(gym)}</p>
                  </div>
                </div>

                <%!-- Stats Row --%>
                <div class="grid grid-cols-2 gap-3">
                  <div class="text-center p-2 rounded-lg bg-base-300/30" id={"gym-location-#{gym.id}"}>
                    <p class="text-lg font-black">{count_loaded(gym.branches)}</p>
                    <p class="text-xs text-base-content/40">Location</p>
                  </div>
                  <div class="text-center p-2 rounded-lg bg-base-300/30" id={"gym-members-#{gym.id}"}>
                    <p class="text-lg font-black">{count_loaded(gym.gym_members)}</p>
                    <p class="text-xs text-base-content/40">Members</p>
                  </div>
                </div>

                <%!-- Promoted Badge --%>
                <%= if gym.is_promoted do %>
                  <div
                    class="flex items-center gap-1.5 text-warning"
                    id={"gym-promoted-badge-#{gym.id}"}
                  >
                    <.icon name="hero-star-solid" class="size-4" />
                    <span class="text-xs font-semibold">Promoted</span>
                  </div>
                <% end %>

                <%!-- Actions --%>
                <div class="flex flex-wrap gap-2 pt-2 border-t border-base-300/50">
                  <%= if gym.status == :pending_verification do %>
                    <button
                      phx-click="verify_gym"
                      phx-value-id={gym.id}
                      class="btn btn-success btn-xs gap-1 font-medium"
                      id={"verify-gym-#{gym.id}"}
                    >
                      <.icon name="hero-shield-check-mini" class="size-3" /> Verify
                    </button>
                  <% end %>

                  <%= if gym.status != :suspended do %>
                    <button
                      phx-click="suspend_gym"
                      phx-value-id={gym.id}
                      class="btn btn-error btn-xs btn-ghost gap-1 font-medium"
                      id={"suspend-gym-#{gym.id}"}
                    >
                      <.icon name="hero-no-symbol-mini" class="size-3" /> Suspend
                    </button>
                  <% end %>

                  <%= if gym.status == :suspended do %>
                    <button
                      phx-click="verify_gym"
                      phx-value-id={gym.id}
                      class="btn btn-success btn-xs gap-1 font-medium"
                      id={"unsuspend-gym-#{gym.id}"}
                    >
                      <.icon name="hero-arrow-path-mini" class="size-3" /> Reinstate
                    </button>
                  <% end %>

                  <button
                    phx-click="toggle_promoted"
                    phx-value-id={gym.id}
                    class={[
                      "btn btn-xs gap-1 font-medium",
                      if(gym.is_promoted,
                        do: "btn-ghost text-warning",
                        else: "btn-ghost text-base-content/50"
                      )
                    ]}
                    id={"toggle-promoted-#{gym.id}"}
                  >
                    <%= if gym.is_promoted do %>
                      <.icon name="hero-star-solid" class="size-3" /> Unpromote
                    <% else %>
                      <.icon name="hero-star" class="size-3" /> Promote
                    <% end %>
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
