defmodule FitTrackerzWeb.Member.BookingsLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "My Bookings",
           memberships: [],
           bookings: [],
           no_gym: true
         )}

      memberships ->
        mids = Enum.map(memberships, & &1.id)

        bookings = case FitTrackerz.Scheduling.list_bookings_by_member(mids, actor: actor, load: [scheduled_class: [:class_definition, :branch]]) do
          {:ok, results} -> Enum.sort_by(results, & &1.inserted_at, {:desc, DateTime})
          _ -> []
        end

        {:ok,
         assign(socket,
           page_title: "My Bookings",
           memberships: memberships,
           bookings: bookings,
           no_gym: false
         )}
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp format_status(status), do: status |> to_string() |> String.capitalize()

  defp status_badge_variant(:pending), do: "warning"
  defp status_badge_variant(:confirmed), do: "success"
  defp status_badge_variant(:declined), do: "error"
  defp status_badge_variant(:cancelled), do: "neutral"
  defp status_badge_variant(_), do: "neutral"

  defp cancellable?(:pending), do: true
  defp cancellable?(:confirmed), do: true
  defp cancellable?(_), do: false

  @impl true
  def handle_event("cancel_booking", %{"booking-id" => booking_id}, socket) do
    actor = socket.assigns.current_user
    booking = Enum.find(socket.assigns.bookings, &(&1.id == booking_id))

    case booking do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking not found.")}

      booking ->
        case FitTrackerz.Scheduling.cancel_booking(booking, %{}, actor: actor) do
          {:ok, _updated} ->
            mids = Enum.map(socket.assigns.memberships, & &1.id)

            bookings = case FitTrackerz.Scheduling.list_bookings_by_member(mids, actor: actor, load: [scheduled_class: [:class_definition, :branch]]) do
              {:ok, results} -> Enum.sort_by(results, & &1.inserted_at, {:desc, DateTime})
              _ -> []
            end

            {:noreply,
             socket
             |> put_flash(:info, "Booking cancelled successfully.")
             |> assign(bookings: bookings)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not cancel this booking.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="My Bookings" subtitle="Track your class bookings and their status." back_path="/member">
        <:actions>
          <.button variant="primary" size="sm" icon="hero-calendar-days" navigate="/member/classes">
            Browse Classes
          </.button>
        </:actions>
      </.page_header>

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You haven't joined any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%= if @bookings == [] do %>
          <.empty_state
            icon="hero-ticket"
            title="No Bookings Yet"
            subtitle="You haven't booked any classes yet. Browse available classes to get started!"
          >
            <:action>
              <.button variant="primary" size="sm" icon="hero-calendar-days" navigate="/member/classes">
                Browse Classes
              </.button>
            </:action>
          </.empty_state>
        <% else %>
          <.card id="bookings-table">
            <.data_table id="bookings" rows={@bookings}>
              <:col :let={booking} label="Class">
                <span class="font-medium">{booking.scheduled_class.class_definition.name}</span>
              </:col>
              <:col :let={booking} label="Location">
                <%= if booking.scheduled_class.branch do %>
                  {booking.scheduled_class.branch.city}
                <% else %>
                  <span class="text-base-content/30">--</span>
                <% end %>
              </:col>
              <:col :let={booking} label="Date & Time">
                <span class="text-base-content/70">{format_datetime(booking.scheduled_class.scheduled_at)}</span>
              </:col>
              <:col :let={booking} label="Status">
                <.badge variant={status_badge_variant(booking.status)}>{format_status(booking.status)}</.badge>
              </:col>
              <:mobile_card :let={booking}>
                <div class="space-y-2">
                  <div class="flex items-center justify-between">
                    <span class="font-semibold">{booking.scheduled_class.class_definition.name}</span>
                    <.badge variant={status_badge_variant(booking.status)} size="sm">{format_status(booking.status)}</.badge>
                  </div>
                  <p class="text-xs text-base-content/60">{format_datetime(booking.scheduled_class.scheduled_at)}</p>
                </div>
              </:mobile_card>
              <:actions :let={booking}>
                <%= if cancellable?(booking.status) do %>
                  <.button
                    variant="ghost"
                    size="sm"
                    phx-click="cancel_booking"
                    phx-value-booking-id={booking.id}
                    data-confirm="Are you sure you want to cancel this booking?"
                    class="text-error"
                  >
                    Cancel
                  </.button>
                <% else %>
                  <span class="text-xs text-base-content/30">--</span>
                <% end %>
              </:actions>
            </.data_table>
          </.card>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
