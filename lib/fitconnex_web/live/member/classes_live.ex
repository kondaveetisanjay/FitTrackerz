defmodule FitconnexWeb.Member.ClassesLive do
  use FitconnexWeb, :live_view

  alias FitconnexWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case Fitconnex.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym, :assigned_trainer]) do
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
        case Fitconnex.Gym.list_branches_by_gym(gid, actor: actor) do
          {:ok, branches} -> Enum.map(branches, & &1.id)
          _ -> []
        end
      end)

    if branch_ids == [] do
      []
    else
      case Fitconnex.Scheduling.list_classes_by_branch(branch_ids, actor: actor, load: [:class_definition, :branch, :trainer, :bookings]) do
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

  @impl true
  def handle_event("book_class", %{"class-id" => class_id, "member-id" => member_id}, socket) do
    actor = socket.assigns.current_user

    case Fitconnex.Scheduling.create_booking(%{
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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Browse Classes</h1>
              <p class="text-base-content/50 mt-1">Discover and book upcoming classes at your gyms.</p>
            </div>
          </div>
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
          <%= if @scheduled_classes == [] do %>
            <%!-- Empty State --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-classes">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-info/10 flex items-center justify-center mb-4">
                  <.icon name="hero-calendar-days" class="size-8 text-info" />
                </div>
                <h2 class="text-lg font-bold">No Upcoming Classes</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  There are no scheduled classes at your gyms right now. Check back later!
                </p>
              </div>
            </div>
          <% else %>
            <%!-- Class Cards Grid --%>
            <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
              <div
                :for={sc <- @scheduled_classes}
                class="card bg-base-200/50 border border-base-300/50"
                id={"class-#{sc.id}"}
              >
                <div class="card-body p-5">
                  <%!-- Class Name & Type --%>
                  <div class="flex items-start justify-between gap-2">
                    <div>
                      <h3 class="text-base font-bold">{sc.class_definition.name}</h3>
                      <span class="badge badge-ghost badge-xs mt-1">
                        {sc.class_definition.class_type}
                      </span>
                    </div>
                    <div class="w-10 h-10 rounded-xl bg-info/10 flex items-center justify-center shrink-0">
                      <.icon name="hero-calendar-days-solid" class="size-5 text-info" />
                    </div>
                  </div>

                  <%!-- Details --%>
                  <div class="mt-4 space-y-2 text-sm">
                    <%!-- Date & Time --%>
                    <div class="flex items-center gap-2 text-base-content/70">
                      <.icon name="hero-clock-mini" class="size-4 text-base-content/40" />
                      <span>{format_datetime(sc.scheduled_at)}</span>
                    </div>
                    <%!-- Duration --%>
                    <div class="flex items-center gap-2 text-base-content/70">
                      <.icon name="hero-arrow-path-mini" class="size-4 text-base-content/40" />
                      <span>{sc.duration_minutes} minutes</span>
                    </div>
                    <%!-- Trainer --%>
                    <%= if sc.trainer do %>
                      <div class="flex items-center gap-2 text-base-content/70">
                        <.icon name="hero-user-mini" class="size-4 text-base-content/40" />
                        <span>{sc.trainer.name}</span>
                      </div>
                    <% end %>
                    <%!-- Location --%>
                    <%= if sc.branch do %>
                      <div class="flex items-center gap-2 text-base-content/70">
                        <.icon name="hero-map-pin-mini" class="size-4 text-base-content/40" />
                        <span>{sc.branch.city}, {sc.branch.address}</span>
                      </div>
                    <% end %>
                  </div>

                  <%!-- Spots & Book Button --%>
                  <div class="mt-4 flex items-center justify-between">
                    <div class="text-xs text-base-content/50">
                      <span class="font-medium">Spots:</span> {spots_available(sc)}
                    </div>
                    <%= if class_full?(sc) do %>
                      <button class="btn btn-sm btn-disabled" disabled>
                        Full
                      </button>
                    <% else %>
                      <%!-- Use first membership's member_id for booking --%>
                      <button
                        class="btn btn-primary btn-sm gap-1"
                        phx-click="book_class"
                        phx-value-class-id={sc.id}
                        phx-value-member-id={hd(@memberships).id}
                      >
                        <.icon name="hero-ticket-mini" class="size-4" /> Book
                      </button>
                    <% end %>
                  </div>
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
