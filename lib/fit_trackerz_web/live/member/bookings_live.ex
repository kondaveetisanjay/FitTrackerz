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

  defp status_badge_class(:pending), do: "badge-warning"
  defp status_badge_class(:confirmed), do: "badge-success"
  defp status_badge_class(:declined), do: "badge-error"
  defp status_badge_class(:cancelled), do: "badge-ghost"
  defp status_badge_class(_), do: "badge-ghost"

  defp format_status(status), do: status |> to_string() |> String.capitalize()

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
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">My Bookings</h1>
              <p class="text-base-content/50 mt-1">Track your class bookings and their status.</p>
            </div>
          </div>
          <a href="/member/classes" class="btn btn-primary btn-sm gap-2 font-semibold">
            <.icon name="hero-calendar-days-mini" class="size-4" /> Browse Classes
          </a>
        </div>

        <%= if @no_gym do %>
          <%!-- No Gym Membership --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <div class="w-16 h-16 rounded-2xl bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-building-office-2" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Membership</h2>
              <p class="text-sm text-base-content/50 max-w-md mt-2">
                You haven't joined any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%= if @bookings == [] do %>
            <%!-- Empty State --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-bookings">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-info/10 flex items-center justify-center mb-4">
                  <.icon name="hero-ticket" class="size-8 text-info" />
                </div>
                <h2 class="text-lg font-bold">No Bookings Yet</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  You haven't booked any classes yet. Browse available classes to get started!
                </p>
                <a href="/member/classes" class="btn btn-primary btn-sm mt-4 gap-2">
                  <.icon name="hero-calendar-days-mini" class="size-4" /> Browse Classes
                </a>
              </div>
            </div>
          <% else %>
            <%!-- Bookings Table --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="bookings-table">
              <div class="card-body p-5">
                <div class="overflow-x-auto">
                  <table class="table table-sm">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Class</th>
                        <th>Location</th>
                        <th>Date & Time</th>
                        <th>Status</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={booking <- @bookings} id={"booking-#{booking.id}"}>
                        <td class="font-medium">
                          {booking.scheduled_class.class_definition.name}
                        </td>
                        <td class="text-base-content/70">
                          <%= if booking.scheduled_class.branch do %>
                            {booking.scheduled_class.branch.city}
                          <% else %>
                            <span class="text-base-content/30">--</span>
                          <% end %>
                        </td>
                        <td class="text-base-content/70">
                          {format_datetime(booking.scheduled_class.scheduled_at)}
                        </td>
                        <td>
                          <span class={"badge badge-sm #{status_badge_class(booking.status)}"}>
                            {format_status(booking.status)}
                          </span>
                        </td>
                        <td>
                          <%= if cancellable?(booking.status) do %>
                            <button
                              class="btn btn-ghost btn-xs text-error"
                              phx-click="cancel_booking"
                              phx-value-booking-id={booking.id}
                              data-confirm="Are you sure you want to cancel this booking?"
                            >
                              Cancel
                            </button>
                          <% else %>
                            <span class="text-xs text-base-content/30">--</span>
                          <% end %>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
