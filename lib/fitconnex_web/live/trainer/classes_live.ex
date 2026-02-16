defmodule FitconnexWeb.Trainer.ClassesLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case Fitconnex.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
      {:ok, trainers} -> trainers
      _ -> []
    end

    if gym_trainers == [] do
      {:ok,
       socket
       |> assign(page_title: "My Classes")
       |> assign(no_gym: true, classes: [], gym_trainer_ids: [])}
    else
      trainer_ids = Enum.map(gym_trainers, & &1.id)
      classes = load_trainer_classes(trainer_ids, actor)

      {:ok,
       socket
       |> assign(page_title: "My Classes")
       |> assign(no_gym: false, classes: classes, gym_trainer_ids: trainer_ids)}
    end
  end

  @impl true
  def handle_event("complete_class", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    trainer_ids = socket.assigns.gym_trainer_ids
    scheduled_class = Enum.find(socket.assigns.classes, &(&1.id == id))

    cond do
      is_nil(scheduled_class) ->
        {:noreply, put_flash(socket, :error, "Class not found.")}

      scheduled_class.trainer_id not in trainer_ids ->
        {:noreply, put_flash(socket, :error, "You are not authorized to manage this class.")}

      true ->
        case Fitconnex.Scheduling.complete_scheduled_class(scheduled_class, %{}, actor: actor) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> assign(classes: load_trainer_classes(trainer_ids, actor))
             |> put_flash(:info, "Class marked as completed.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to complete class.")}
        end
    end
  end

  @impl true
  def handle_event("cancel_class", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    trainer_ids = socket.assigns.gym_trainer_ids
    scheduled_class = Enum.find(socket.assigns.classes, &(&1.id == id))

    cond do
      is_nil(scheduled_class) ->
        {:noreply, put_flash(socket, :error, "Class not found.")}

      scheduled_class.trainer_id not in trainer_ids ->
        {:noreply, put_flash(socket, :error, "You are not authorized to manage this class.")}

      true ->
        case Fitconnex.Scheduling.cancel_scheduled_class(scheduled_class, %{}, actor: actor) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> assign(classes: load_trainer_classes(trainer_ids, actor))
             |> put_flash(:info, "Class has been cancelled.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to cancel class.")}
        end
    end
  end

  defp load_trainer_classes(trainer_ids, actor) do
    case Fitconnex.Scheduling.list_classes_by_trainer(trainer_ids, actor: actor, load: [:class_definition, :branch, :bookings]) do
      {:ok, classes} -> classes
      _ -> []
    end
  end

  defp status_badge_class(status) do
    case status do
      :scheduled -> "badge-info"
      :completed -> "badge-success"
      :cancelled -> "badge-error"
      _ -> "badge-ghost"
    end
  end

  defp format_status(status) do
    status |> to_string() |> String.capitalize()
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%b %d, %Y at %I:%M %p")
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
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">My Classes</h1>
              <p class="text-base-content/50 mt-1">View and manage your scheduled classes.</p>
            </div>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-notice">
            <div class="card-body p-8 items-center text-center">
              <div class="w-16 h-16 rounded-full bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-exclamation-triangle-solid" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Association</h2>
              <p class="text-base-content/50 mt-2 max-w-md">
                You haven't been added to any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Stats Row --%>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-total-classes">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Total Classes
                    </p>
                    <p class="text-3xl font-black mt-1">{length(@classes)}</p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-calendar-days-solid" class="size-6 text-info" />
                  </div>
                </div>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-scheduled-classes">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Scheduled
                    </p>
                    <p class="text-3xl font-black mt-1">
                      {Enum.count(@classes, &(&1.status == :scheduled))}
                    </p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-clock-solid" class="size-6 text-primary" />
                  </div>
                </div>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-completed-classes">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Completed
                    </p>
                    <p class="text-3xl font-black mt-1">
                      {Enum.count(@classes, &(&1.status == :completed))}
                    </p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-success/10 flex items-center justify-center">
                    <.icon name="hero-check-circle-solid" class="size-6 text-success" />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Classes Table --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="classes-table-card">
            <div class="card-body p-5">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-calendar-days-solid" class="size-5 text-info" /> Scheduled Classes
              </h2>
              <div class="mt-4 overflow-x-auto">
                <table class="table table-sm" id="classes-table">
                  <thead>
                    <tr class="text-base-content/40">
                      <th>Class Name</th>
                      <th>Location</th>
                      <th>Scheduled At</th>
                      <th>Duration</th>
                      <th>Status</th>
                      <th>Bookings</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @classes == [] do %>
                      <tr id="classes-empty-row">
                        <td colspan="7" class="text-center text-base-content/40 py-8">
                          No classes scheduled yet. Classes will appear here once scheduled by the gym operator.
                        </td>
                      </tr>
                    <% else %>
                      <tr :for={class <- @classes} id={"class-row-#{class.id}"}>
                        <td class="font-medium">
                          {if class.class_definition, do: class.class_definition.name, else: "N/A"}
                        </td>
                        <td class="text-base-content/60">
                          {if class.branch,
                            do: "#{class.branch.city}, #{class.branch.address}",
                            else: "N/A"}
                        </td>
                        <td class="text-base-content/60">
                          {format_datetime(class.scheduled_at)}
                        </td>
                        <td class="text-base-content/60">
                          {class.duration_minutes} min
                        </td>
                        <td>
                          <span class={"badge badge-sm #{status_badge_class(class.status)}"}>
                            {format_status(class.status)}
                          </span>
                        </td>
                        <td class="text-base-content/60">
                          <span class="flex items-center gap-1">
                            <.icon name="hero-user-group-mini" class="size-4" />
                            {length(class.bookings || [])}
                          </span>
                        </td>
                        <td>
                          <%= if class.status == :scheduled do %>
                            <div class="flex gap-1">
                              <button
                                class="btn btn-success btn-xs gap-1"
                                phx-click="complete_class"
                                phx-value-id={class.id}
                                data-confirm="Mark this class as completed?"
                                id={"complete-class-#{class.id}"}
                              >
                                <.icon name="hero-check-mini" class="size-3" /> Complete
                              </button>
                              <button
                                class="btn btn-error btn-xs gap-1"
                                phx-click="cancel_class"
                                phx-value-id={class.id}
                                data-confirm="Are you sure you want to cancel this class?"
                                id={"cancel-class-#{class.id}"}
                              >
                                <.icon name="hero-x-mark-mini" class="size-3" /> Cancel
                              </button>
                            </div>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
