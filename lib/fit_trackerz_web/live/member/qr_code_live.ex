defmodule FitTrackerzWeb.Member.QrCodeLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships =
      case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
        {:ok, memberships} -> memberships
        _ -> []
      end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "My QR Code",
           no_gym: true,
           token_url: nil,
           expires_at: nil,
           is_premium: false,
           recent_checkins: []
         )}

      memberships ->
        membership = List.first(memberships)
        gym = membership.gym
        is_premium = gym.tier == :premium

        # Load existing active QR token
        {token_url, expires_at} = load_active_token(membership.id, actor)

        recent_checkins =
          case FitTrackerz.Training.list_qr_check_ins_by_member(membership.id, actor: actor) do
            {:ok, checkins} -> checkins
            _ -> []
          end

        {:ok,
         assign(socket,
           page_title: "My QR Code",
           no_gym: false,
           membership: membership,
           gym: gym,
           is_premium: is_premium,
           token_url: token_url,
           expires_at: expires_at,
           recent_checkins: recent_checkins
         )}
    end
  end

  @impl true
  def handle_event("generate", _params, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    case FitTrackerz.Training.generate_qr_check_in(
           %{gym_member_id: membership.id},
           actor: actor
         ) do
      {:ok, qr} ->
        token_url = "#{FitTrackerzWeb.Endpoint.url()}/gym/checkin/#{qr.token}"

        {:noreply,
         socket
         |> put_flash(:info, "QR code generated! Show this to your gym staff to check in.")
         |> assign(token_url: token_url, expires_at: qr.expires_at)}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
    end
  end

  defp load_active_token(membership_id, actor) do
    case FitTrackerz.Training.list_qr_check_ins_by_member(membership_id, actor: actor) do
      {:ok, [latest | _]} ->
        if latest.status == :active &&
             DateTime.compare(latest.expires_at, DateTime.utc_now()) == :gt do
          url = "#{FitTrackerzWeb.Endpoint.url()}/gym/checkin/#{latest.token}"
          {url, latest.expires_at}
        else
          {nil, nil}
        end

      _ ->
        {nil, nil}
    end
  end

  defp format_expiry(nil), do: ""

  defp format_expiry(expires_at) do
    diff = DateTime.diff(expires_at, DateTime.utc_now(), :minute)

    cond do
      diff <= 0 -> "Expired"
      diff < 60 -> "#{diff} min"
      true -> "#{div(diff, 60)}h #{rem(diff, 60)}m"
    end
  end

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%b %d, %Y at %I:%M %p")
  end

  defp status_badge_variant(:active), do: "success"
  defp status_badge_variant(:used), do: "neutral"
  defp status_badge_variant(:expired), do: "error"
  defp status_badge_variant(_), do: "neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="My QR Code" subtitle="Generate a QR code for gym check-in." back_path="/member/attendance" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You need a gym membership to use QR check-in."
        />
      <% else %>
        <%= if !@is_premium do %>
          <.card>
            <.empty_state
              icon="hero-lock-closed"
              title="Premium Feature"
              subtitle="QR check-in is available for Premium gym members. Ask your gym operator to upgrade."
            />
          </.card>
        <% else %>
          <div class="max-w-md mx-auto space-y-6">
            <.card>
              <div class="flex flex-col items-center space-y-4 py-4">
                <%= if @token_url do %>
                  <div
                    id="qr-canvas"
                    phx-hook="QrCode"
                    data-url={@token_url}
                    phx-update="ignore"
                    class="bg-white p-4 rounded-xl"
                  >
                  </div>
                  <p class="text-sm text-base-content/50 text-center break-all max-w-xs">{@token_url}</p>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-clock" class="size-4 text-base-content/40" />
                    <span class="text-sm text-base-content/60">Expires in {format_expiry(@expires_at)}</span>
                  </div>
                  <.button variant="ghost" size="sm" icon="hero-arrow-path" phx-click="generate" id="regenerate-btn">
                    Regenerate
                  </.button>
                <% else %>
                  <.icon name="hero-qr-code" class="size-24 text-base-content/20" />
                  <p class="text-base-content/50 text-center">Generate a QR code and show it to your gym staff to check in.</p>
                  <.button variant="primary" icon="hero-qr-code" phx-click="generate" id="generate-btn">
                    Generate QR Code
                  </.button>
                <% end %>
              </div>
            </.card>

            <%= if @recent_checkins != [] do %>
              <.card title="Recent Tokens" id="recent-tokens">
                <div class="space-y-3">
                  <div :for={checkin <- @recent_checkins} class="flex items-center justify-between py-2 border-b border-base-300/30 last:border-0">
                    <div>
                      <p class="text-sm font-mono text-base-content/50">{String.slice(checkin.token, 0..7)}...</p>
                      <p class="text-xs text-base-content/40">{format_datetime(checkin.inserted_at)}</p>
                    </div>
                    <.badge variant={status_badge_variant(checkin.status)} size="sm">
                      {checkin.status |> to_string() |> String.capitalize()}
                    </.badge>
                  </div>
                </div>
              </.card>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
