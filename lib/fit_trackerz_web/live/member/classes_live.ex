defmodule FitTrackerzWeb.Member.ClassesLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

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
           page_title: "Browse Classes",
           memberships: [],
           scheduled_classes: [],
           no_gym: true
         )}

      memberships ->
        scheduled_classes = load_scheduled_classes(memberships, actor)

        {:ok,
         assign(socket,
           page_title: "Browse Classes",
           memberships: memberships,
           scheduled_classes: scheduled_classes,
           no_gym: false
         )}
    end
  end

  defp load_scheduled_classes(memberships, actor) do
    gids = memberships |> Enum.map(& &1.gym_id) |> Enum.uniq()

    branch_ids =
      gids
      |> Enum.flat_map(fn gid ->
        case FitTrackerz.Gym.list_branches_by_gym(gid, actor: actor) do
          {:ok, branches} -> Enum.map(branches, & &1.id)
          _ -> []
        end
      end)

    if branch_ids == [] do
      []
    else
      case FitTrackerz.Scheduling.list_classes_by_branch(branch_ids, actor: actor, load: [:class_definition, :branch, :bookings]) do
        {:ok, classes} -> Enum.sort_by(classes, & &1.scheduled_at, DateTime)
        _ -> []
      end
    end
  end

  defp spots_available(scheduled_class) do
    max = get_max_participants(scheduled_class)

    booked =
      scheduled_class.bookings |> Enum.count(fn b -> b.status in [:pending, :confirmed] end)

    case max do
      nil -> "Unlimited"
      max_val -> "#{max(max_val - booked, 0)} / #{max_val}"
    end
  end

  defp class_full?(scheduled_class) do
    max = get_max_participants(scheduled_class)

    case max do
      nil ->
        false

      max_val ->
        booked =
          scheduled_class.bookings |> Enum.count(fn b -> b.status in [:pending, :confirmed] end)

        booked >= max_val
    end
  end

  defp get_max_participants(scheduled_class) do
    case scheduled_class.class_definition do
      %{max_participants: max} when not is_nil(max) -> max
      _ -> nil
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp membership_for_class([], _scheduled_class), do: nil
  defp membership_for_class(memberships, scheduled_class) do
    gym_id = if scheduled_class.branch, do: scheduled_class.branch.gym_id, else: nil

    Enum.find(memberships, List.first(memberships), fn m -> m.gym_id == gym_id end)
  end

  @impl true
  def handle_event("book_class", %{"class-id" => class_id, "member-id" => member_id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Scheduling.create_booking(%{
      scheduled_class_id: class_id,
      member_id: member_id
    }, actor: actor) do
      {:ok, _booking} ->
        scheduled_classes = load_scheduled_classes(socket.assigns.memberships, actor)

        {:noreply,
         socket
         |> put_flash(:info, "Class booked successfully! Check your bookings for status updates.")
         |> assign(scheduled_classes: scheduled_classes)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="Browse Classes" subtitle="Discover and book upcoming classes at your gyms." back_path="/member" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You haven't joined any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%= if @scheduled_classes == [] do %>
          <.empty_state
            icon="hero-calendar-days"
            title="No Upcoming Classes"
            subtitle="There are no scheduled classes at your gyms right now. Check back later!"
          />
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 sm:gap-6">
            <div
              :for={sc <- @scheduled_classes}
              id={"class-#{sc.id}"}
            >
              <.card>
                <div class="space-y-4">
                  <%!-- Class Name & Type --%>
                  <div class="flex items-start justify-between gap-2">
                    <div>
                      <h3 class="text-lg font-bold">{sc.class_definition.name}</h3>
                      <.badge variant="neutral" size="sm" class="mt-1">
                        {sc.class_definition.class_type}
                      </.badge>
                    </div>
                    <div class="w-10 h-10 rounded-xl bg-info/10 flex items-center justify-center shrink-0">
                      <.icon name="hero-calendar-days-solid" class="size-5 text-info" />
                    </div>
                  </div>

                  <%!-- Details --%>
                  <div class="space-y-2 text-sm">
                    <div class="flex items-center gap-2 text-base-content/70">
                      <.icon name="hero-clock-mini" class="size-4 text-base-content/40" />
                      <span>{format_datetime(sc.scheduled_at)}</span>
                    </div>
                    <div class="flex items-center gap-2 text-base-content/70">
                      <.icon name="hero-arrow-path-mini" class="size-4 text-base-content/40" />
                      <span>{sc.duration_minutes} minutes</span>
                    </div>
                    <%= if sc.branch do %>
                      <div class="flex items-center gap-2 text-base-content/70">
                        <.icon name="hero-map-pin-mini" class="size-4 text-base-content/40" />
                        <span>{sc.branch.city}, {sc.branch.address}</span>
                      </div>
                    <% end %>
                  </div>

                  <%!-- Spots & Book Button --%>
                  <div class="flex items-center justify-between pt-2 border-t border-base-300/30">
                    <div class="text-sm text-base-content/50">
                      <span class="font-medium">Spots:</span> {spots_available(sc)}
                    </div>
                    <%= if class_full?(sc) do %>
                      <.badge variant="error">Full</.badge>
                    <% else %>
                      <% membership = membership_for_class(@memberships, sc) %>
                      <%= if membership do %>
                        <.button
                          variant="primary"
                          size="sm"
                          icon="hero-ticket"
                          phx-click="book_class"
                          phx-value-class-id={sc.id}
                          phx-value-member-id={membership.id}
                        >
                          Book
                        </.button>
                      <% end %>
                    <% end %>
                  </div>
                </div>
              </.card>
            </div>
          </div>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
