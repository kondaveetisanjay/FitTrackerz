defmodule FitTrackerzWeb.Trainer.ClassesLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case FitTrackerz.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
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
        case FitTrackerz.Scheduling.complete_scheduled_class(scheduled_class, %{}, actor: actor) do
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
        case FitTrackerz.Scheduling.cancel_scheduled_class(scheduled_class, %{}, actor: actor) do
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
    case FitTrackerz.Scheduling.list_classes_by_trainer(trainer_ids, actor: actor, load: [:class_definition, :branch, :bookings]) do
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
      <.page_header title="My Classes" subtitle="View and manage your scheduled classes." back_path="/trainer" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-exclamation-triangle"
          title="No Gym Association"
          subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%!-- Stats Row --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-8">
          <.stat_card label="Total Classes" value={length(@classes)} icon="hero-calendar-days-solid" color="info" />
          <.stat_card label="Scheduled" value={Enum.count(@classes, &(&1.status == :scheduled))} icon="hero-clock-solid" color="primary" />
          <.stat_card label="Completed" value={Enum.count(@classes, &(&1.status == :completed))} icon="hero-check-circle-solid" color="success" />
        </div>

        <%!-- Classes Table --%>
        <.card title="Scheduled Classes">
          <%= if @classes == [] do %>
            <.empty_state
              icon="hero-calendar-days"
              title="No classes scheduled yet"
              subtitle="Classes will appear here once scheduled by the gym operator."
            />
          <% else %>
            <.data_table id="classes-table" rows={@classes} row_id={fn c -> "class-#{c.id}" end}>
              <:col :let={class} label="Class Name">
                <span class="font-medium">
                  {if class.class_definition, do: class.class_definition.name, else: "N/A"}
                </span>
              </:col>
              <:col :let={class} label="Location">
                {if class.branch, do: "#{class.branch.city}, #{class.branch.address}", else: "N/A"}
              </:col>
              <:col :let={class} label="Scheduled At">
                {format_datetime(class.scheduled_at)}
              </:col>
              <:col :let={class} label="Duration">
                {class.duration_minutes} min
              </:col>
              <:col :let={class} label="Status">
                <span class={"badge badge-sm #{status_badge_class(class.status)}"}>
                  {format_status(class.status)}
                </span>
              </:col>
              <:col :let={class} label="Bookings">
                <span class="flex items-center gap-1">
                  <.icon name="hero-user-group-mini" class="size-4" />
                  {length(class.bookings || [])}
                </span>
              </:col>
              <:actions :let={class}>
                <%= if class.status == :scheduled do %>
                  <div class="flex gap-1">
                    <.button
                      variant="primary"
                      size="sm"
                      icon="hero-check"
                      phx-click="complete_class"
                      phx-value-id={class.id}
                      data-confirm="Mark this class as completed?"
                      id={"complete-class-#{class.id}"}
                    >
                      Complete
                    </.button>
                    <.button
                      variant="danger"
                      size="sm"
                      icon="hero-x-mark"
                      phx-click="cancel_class"
                      phx-value-id={class.id}
                      data-confirm="Are you sure you want to cancel this class?"
                      id={"cancel-class-#{class.id}"}
                    >
                      Cancel
                    </.button>
                  </div>
                <% end %>
              </:actions>
              <:mobile_card :let={class}>
                <div>
                  <p class="font-semibold">
                    {if class.class_definition, do: class.class_definition.name, else: "N/A"}
                  </p>
                  <p class="text-xs text-base-content/50 mt-1">
                    {format_datetime(class.scheduled_at)} &middot; {class.duration_minutes} min
                  </p>
                  <div class="mt-1">
                    <span class={"badge badge-sm #{status_badge_class(class.status)}"}>
                      {format_status(class.status)}
                    </span>
                  </div>
                </div>
              </:mobile_card>
            </.data_table>
          <% end %>
        </.card>
      <% end %>
    </Layouts.app>
    """
  end
end
