defmodule FitTrackerzWeb.GymOperator.CheckinLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "QR Check-in")}
  end

  @impl true
  def handle_params(%{"token" => token}, _uri, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Training.get_qr_check_in_by_token(token, actor: actor, load: [gym_member: [:user, :gym]]) do
      {:ok, qr} ->
        expired? =
          qr.status == :active &&
            DateTime.compare(qr.expires_at, DateTime.utc_now()) == :lt

        {:noreply,
         assign(socket,
           qr: qr,
           member_name: qr.gym_member.user.name,
           gym_name: qr.gym_member.gym.name,
           redeemed: false,
           expired: expired?,
           not_found: false
         )}

      {:error, _} ->
        {:noreply,
         assign(socket,
           qr: nil,
           not_found: true,
           redeemed: false,
           expired: false,
           member_name: nil,
           gym_name: nil
         )}
    end
  end

  @impl true
  def handle_event("redeem", _params, socket) do
    actor = socket.assigns.current_user
    qr = socket.assigns.qr

    case FitTrackerz.Training.redeem_qr_check_in(qr, actor: actor) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Check-in recorded successfully!")
         |> assign(redeemed: true)}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="QR Check-in" subtitle="Scan and confirm member check-in." back_path="/gym/attendance" />

      <div class="max-w-md mx-auto">
        <.card>
          <%= cond do %>
            <% @not_found -> %>
              <.empty_state
                icon="hero-exclamation-triangle"
                title="Token Not Found"
                subtitle="This QR code is invalid or does not exist."
              />

            <% @redeemed -> %>
              <div class="text-center py-8 space-y-4">
                <div class="size-16 rounded-full bg-success/20 flex items-center justify-center mx-auto">
                  <.icon name="hero-check-circle-solid" class="size-10 text-success" />
                </div>
                <h3 class="text-xl font-bold">Check-in Confirmed!</h3>
                <p class="text-base-content/60">{@member_name} has been checked in at {@gym_name}.</p>
                <.button variant="ghost" navigate="/gym/attendance" icon="hero-arrow-left">
                  Back to Attendance
                </.button>
              </div>

            <% @expired || (@qr && @qr.status != :active) -> %>
              <.empty_state
                icon="hero-clock"
                title={if @qr.status == :used, do: "Already Used", else: "QR Code Expired"}
                subtitle={if @qr.status == :used, do: "This QR code has already been redeemed.", else: "This QR code has expired. Ask the member to generate a new one."}
              />

            <% @qr && @qr.status == :active -> %>
              <div class="text-center py-6 space-y-6">
                <div class="space-y-2">
                  <.avatar name={@member_name} size="lg" />
                  <h3 class="text-lg font-bold">{@member_name}</h3>
                  <p class="text-sm text-base-content/50">{@gym_name}</p>
                </div>
                <.badge variant="success" size="sm">Valid QR Code</.badge>
                <div>
                  <.button variant="primary" size="lg" icon="hero-check-circle" phx-click="redeem" id="redeem-btn">
                    Confirm Check-in
                  </.button>
                </div>
              </div>

            <% true -> %>
              <.empty_state icon="hero-question-mark-circle" title="Unknown State" subtitle="Something unexpected happened." />
          <% end %>
        </.card>
      </div>
    </Layouts.app>
    """
  end
end
