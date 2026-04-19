defmodule FitTrackerzWeb.Admin.GymsLive do
  use FitTrackerzWeb, :live_view

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

  defp status_badge_variant(:verified), do: "success"
  defp status_badge_variant(:pending_verification), do: "warning"
  defp status_badge_variant(:suspended), do: "error"
  defp status_badge_variant(_), do: "neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="Gyms" subtitle={"#{length(@gyms)} total gyms on the platform"} back_path="/admin/dashboard" />

      <%= if Enum.empty?(@gyms) do %>
        <.card>
          <.empty_state
            icon="hero-building-office-2"
            title="No gyms found"
            subtitle="Gyms will appear here once operators create them."
          />
        </.card>
      <% else %>
        <.card padded={false}>
          <.data_table id="gyms-table" rows={@gyms} row_id={fn gym -> "gym-row-#{gym.id}" end}>
            <:col :let={gym} label="Gym">
              <div class="min-w-0">
                <p class="font-semibold truncate" id={"gym-name-#{gym.id}"}>{gym.name}</p>
                <p class="text-xs text-base-content/40 font-mono" id={"gym-slug-#{gym.id}"}>{gym.slug}</p>
              </div>
            </:col>
            <:col :let={gym} label="Owner">
              <div class="flex items-center gap-2">
                <.avatar name={owner_name(gym)} size="sm" />
                <span class="text-sm" id={"gym-owner-#{gym.id}"}>{owner_name(gym)}</span>
              </div>
            </:col>
            <:col :let={gym} label="Status">
              <div class="flex items-center gap-2">
                <.badge variant={status_badge_variant(gym.status)} size="sm">
                  {format_status(gym.status)}
                </.badge>
                <.badge :if={gym.is_promoted} variant="warning" size="sm">
                  <.icon name="hero-star-solid" class="size-3 mr-0.5" /> Promoted
                </.badge>
              </div>
            </:col>
            <:col :let={gym} label="Locations">
              <span class="font-semibold" id={"gym-location-#{gym.id}"}>{count_loaded(gym.branches)}</span>
            </:col>
            <:col :let={gym} label="Members">
              <span class="font-semibold" id={"gym-members-#{gym.id}"}>{count_loaded(gym.gym_members)}</span>
            </:col>
            <:mobile_card :let={gym}>
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <p class="font-semibold">{gym.name}</p>
                  <.badge variant={status_badge_variant(gym.status)} size="sm">{format_status(gym.status)}</.badge>
                </div>
                <p class="text-xs text-base-content/50">Owner: {owner_name(gym)}</p>
                <div class="flex items-center gap-3 mt-1 text-xs text-base-content/60">
                  <span>{count_loaded(gym.branches)} locations</span>
                  <span>{count_loaded(gym.gym_members)} members</span>
                  <.badge :if={gym.is_promoted} variant="warning" size="sm">Promoted</.badge>
                </div>
              </div>
            </:mobile_card>
            <:actions :let={gym}>
              <div class="flex items-center gap-1">
                <%= if gym.status == :pending_verification do %>
                  <.button
                    variant="primary"
                    size="sm"
                    icon="hero-shield-check-mini"
                    phx-click="verify_gym"
                    phx-value-id={gym.id}
                  >
                    Verify
                  </.button>
                <% end %>

                <%= if gym.status != :suspended do %>
                  <.button
                    variant="danger"
                    size="sm"
                    icon="hero-no-symbol-mini"
                    phx-click="suspend_gym"
                    phx-value-id={gym.id}
                  >
                    Suspend
                  </.button>
                <% end %>

                <%= if gym.status == :suspended do %>
                  <.button
                    variant="primary"
                    size="sm"
                    icon="hero-arrow-path-mini"
                    phx-click="verify_gym"
                    phx-value-id={gym.id}
                  >
                    Reinstate
                  </.button>
                <% end %>

                <.button
                  variant="ghost"
                  size="sm"
                  icon={if(gym.is_promoted, do: "hero-star-solid", else: "hero-star")}
                  phx-click="toggle_promoted"
                  phx-value-id={gym.id}
                >
                  <%= if gym.is_promoted do %>
                    Unpromote
                  <% else %>
                    Promote
                  <% end %>
                </.button>
              </div>
            </:actions>
          </.data_table>
        </.card>
      <% end %>
    </Layouts.app>
    """
  end
end
