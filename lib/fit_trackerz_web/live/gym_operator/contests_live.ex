defmodule FitTrackerzWeb.GymOperator.ContestsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @contest_types [
    {:challenge, "Challenge"},
    {:competition, "Competition"},
    {:event, "Event"},
    {:other, "Other"}
  ]

  @status_options [
    {:upcoming, "Upcoming"},
    {:active, "Active"},
    {:completed, "Completed"},
    {:cancelled, "Cancelled"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case find_gym(actor) do
      {:ok, gym} ->
        contests = load_contests(gym.id, actor)

        {:ok,
         assign(socket,
           page_title: "Contests",
           gym: gym,
           contests: contests,
           show_form: false,
           editing_contest_id: nil,
           form: new_form(),
           contest_types: @contest_types,
           status_options: @status_options
         )}

      :no_gym ->
        {:ok,
         assign(socket,
           page_title: "Contests",
           gym: nil,
           contests: [],
           show_form: false,
           editing_contest_id: nil,
           form: new_form(),
           contest_types: @contest_types,
           status_options: @status_options
         )}
    end
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_form: !socket.assigns.show_form,
       editing_contest_id: nil,
       form: new_form()
     )}
  end

  def handle_event("validate", %{"contest" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save_contest", %{"contest" => params}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    max_p =
      case Integer.parse(params["max_participants"] || "") do
        {n, _} -> n
        :error -> nil
      end

    create_params = %{
      title: params["title"],
      description: params["description"],
      contest_type: params["contest_type"],
      status: params["status"] || "upcoming",
      starts_at: parse_datetime(params["starts_at"]),
      ends_at: parse_datetime(params["ends_at"]),
      max_participants: max_p,
      prize_description: params["prize_description"],
      gym_id: gym.id
    }

    case FitTrackerz.Gym.create_contest(create_params, actor: actor) do
      {:ok, _contest} ->
        contests = load_contests(gym.id, actor)

        {:noreply,
         socket
         |> put_flash(:info, "Contest created successfully!")
         |> assign(contests: contests, show_form: false, form: new_form())}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("edit_contest", %{"id" => id}, socket) do
    contest = Enum.find(socket.assigns.contests, &(&1.id == id))

    if contest do
      edit_form =
        to_form(
          %{
            "title" => contest.title || "",
            "description" => contest.description || "",
            "contest_type" => to_string(contest.contest_type),
            "status" => to_string(contest.status),
            "starts_at" => format_datetime_local(contest.starts_at),
            "ends_at" => format_datetime_local(contest.ends_at),
            "max_participants" => if(contest.max_participants, do: to_string(contest.max_participants), else: ""),
            "prize_description" => contest.prize_description || ""
          },
          as: "contest"
        )

      {:noreply, assign(socket, editing_contest_id: id, form: edit_form, show_form: false)}
    else
      {:noreply, put_flash(socket, :error, "Contest not found.")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_contest_id: nil, form: new_form())}
  end

  def handle_event("update_contest", %{"contest" => params}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym
    contest = Enum.find(socket.assigns.contests, &(&1.id == socket.assigns.editing_contest_id))

    if contest do
      max_p =
        case Integer.parse(params["max_participants"] || "") do
          {n, _} -> n
          :error -> nil
        end

      update_params = %{
        title: params["title"],
        description: params["description"],
        contest_type: params["contest_type"],
        status: params["status"],
        starts_at: parse_datetime(params["starts_at"]),
        ends_at: parse_datetime(params["ends_at"]),
        max_participants: max_p,
        prize_description: params["prize_description"]
      }

      case FitTrackerz.Gym.update_contest(contest, update_params, actor: actor) do
        {:ok, _updated} ->
          contests = load_contests(gym.id, actor)

          {:noreply,
           socket
           |> put_flash(:info, "Contest updated successfully!")
           |> assign(contests: contests, editing_contest_id: nil, form: new_form())}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    else
      {:noreply, put_flash(socket, :error, "Contest not found.")}
    end
  end

  def handle_event("delete_contest", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym
    contest = Enum.find(socket.assigns.contests, &(&1.id == id))

    if contest do
      case FitTrackerz.Gym.destroy_contest(contest, actor: actor) do
        :ok ->
          contests = load_contests(gym.id, actor)

          {:noreply,
           socket
           |> put_flash(:info, "Contest deleted.")
           |> assign(contests: contests, editing_contest_id: nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete contest.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Contest not found.")}
    end
  end

  # -- Helpers --

  defp find_gym(actor) do
    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} -> {:ok, gym}
      _ -> :no_gym
    end
  end

  defp load_contests(gym_id, actor) do
    case FitTrackerz.Gym.list_contests_by_gym(gym_id, actor: actor) do
      {:ok, contests} -> contests
      _ -> []
    end
  end

  defp new_form do
    to_form(
      %{
        "title" => "",
        "description" => "",
        "contest_type" => "challenge",
        "status" => "upcoming",
        "starts_at" => "",
        "ends_at" => "",
        "max_participants" => "",
        "prize_description" => ""
      },
      as: "contest"
    )
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str <> ":00Z") do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp format_datetime_local(nil), do: ""

  defp format_datetime_local(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%dT%H:%M")
  end

  defp format_date(nil), do: ""

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y")
  end

  defp type_badge_variant(:challenge), do: "warning"
  defp type_badge_variant(:competition), do: "error"
  defp type_badge_variant(:event), do: "info"
  defp type_badge_variant(_), do: "neutral"

  defp status_badge_variant(:upcoming), do: "info"
  defp status_badge_variant(:active), do: "success"
  defp status_badge_variant(:completed), do: "neutral"
  defp status_badge_variant(:cancelled), do: "error"
  defp status_badge_variant(_), do: "neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <.page_header title="Contests" subtitle="Create and manage fitness contests for your gym." back_path="/gym">
          <:actions>
            <%= if @gym do %>
              <.button variant="primary" size="sm" icon="hero-plus-mini" phx-click="toggle_form" id="toggle-contest-form">New Contest</.button>
            <% end %>
          </:actions>
        </.page_header>

        <%= if @gym == nil do %>
          <.empty_state icon="hero-building-office-solid" title="No Gym Found" subtitle="You need to create a gym first before managing contests.">
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus-mini" navigate="/gym/setup">Setup Gym</.button>
            </:action>
          </.empty_state>
        <% else %>
          <%!-- Create Form --%>
          <%= if @show_form do %>
            <.card title="New Contest" id="create-contest-card">
              <.form
                for={@form}
                id="create-contest-form"
                phx-change="validate"
                phx-submit="save_contest"
              >
                {render_contest_fields(assigns)}
                <div class="flex gap-2 mt-4">
                  <.button variant="primary" size="sm" icon="hero-check-mini" type="submit" id="save-contest-btn">Create Contest</.button>
                  <.button variant="ghost" size="sm" type="button" phx-click="toggle_form" id="cancel-create-btn">Cancel</.button>
                </div>
              </.form>
            </.card>
          <% end %>

          <%!-- Edit Form --%>
          <%= if @editing_contest_id do %>
            <.card title="Edit Contest" id="edit-contest-card">
              <.form
                for={@form}
                id="edit-contest-form"
                phx-change="validate"
                phx-submit="update_contest"
              >
                {render_contest_fields(assigns)}
                <div class="flex gap-2 mt-4">
                  <.button variant="primary" size="sm" icon="hero-check-mini" type="submit" id="update-contest-btn">Update</.button>
                  <.button variant="ghost" size="sm" type="button" phx-click="cancel_edit" id="cancel-edit-btn">Cancel</.button>
                </div>
              </.form>
            </.card>
          <% end %>

          <%!-- Contest List --%>
          <%= if @contests == [] do %>
            <.empty_state icon="hero-trophy-solid" title="No Contests Yet" subtitle="Create fitness contests to engage your members with challenges, competitions, and events.">
              <:action>
                <.button variant="primary" icon="hero-plus-mini" phx-click="toggle_form">Create Contest</.button>
              </:action>
            </.empty_state>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="contests-grid">
              <%= for contest <- @contests do %>
                <.card class="overflow-hidden" id={"contest-#{contest.id}"}>
                  <div class="space-y-3">
                    <%!-- Badges --%>
                    <div class="flex flex-wrap gap-1.5">
                      <.badge variant={type_badge_variant(contest.contest_type)}>
                        {contest.contest_type |> to_string() |> String.capitalize()}
                      </.badge>
                      <.badge variant={status_badge_variant(contest.status)}>
                        {contest.status |> to_string() |> String.capitalize()}
                      </.badge>
                    </div>

                    <h3 class="font-bold text-base leading-tight">{contest.title}</h3>

                    <%= if contest.description do %>
                      <p class="text-sm text-base-content/60 line-clamp-2">{contest.description}</p>
                    <% end %>

                    <div class="flex items-center gap-1.5 text-sm text-base-content/60">
                      <.icon name="hero-calendar-mini" class="size-3.5 shrink-0" />
                      <span>{format_date(contest.starts_at)} -- {format_date(contest.ends_at)}</span>
                    </div>

                    <%= if contest.max_participants do %>
                      <div class="flex items-center gap-1.5 text-sm text-base-content/60">
                        <.icon name="hero-users-mini" class="size-3.5 shrink-0" />
                        <span>{contest.max_participants} max participants</span>
                      </div>
                    <% end %>

                    <%= if contest.prize_description do %>
                      <div class="flex items-start gap-1.5 text-sm text-base-content/60">
                        <.icon name="hero-gift-mini" class="size-3.5 shrink-0 mt-0.5" />
                        <span class="line-clamp-1">{contest.prize_description}</span>
                      </div>
                    <% end %>

                    <div class="flex gap-2 pt-2 border-t border-base-300/30">
                      <.button variant="ghost" size="sm" icon="hero-pencil-square" phx-click="edit_contest" phx-value-id={contest.id} id={"edit-#{contest.id}"}>Edit</.button>
                      <.button variant="ghost" size="sm" icon="hero-trash" phx-click="delete_contest" phx-value-id={contest.id} data-confirm="Are you sure you want to delete this contest?" id={"delete-#{contest.id}"} class="text-error">Delete</.button>
                    </div>
                  </div>
                </.card>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_contest_fields(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <.input field={@form[:title]} label="Title" placeholder="e.g. 30-Day Weight Loss Challenge" />
      <.input
        field={@form[:contest_type]}
        type="select"
        label="Contest Type"
        options={Enum.map(@contest_types, fn {v, l} -> {l, to_string(v)} end)}
      />
      <div class="md:col-span-2">
        <.input
          field={@form[:description]}
          type="textarea"
          label="Description"
          placeholder="Describe the contest rules, goals, and how participants can join..."
        />
      </div>
      <.input field={@form[:starts_at]} type="datetime-local" label="Start Date" />
      <.input field={@form[:ends_at]} type="datetime-local" label="End Date" />
      <.input
        field={@form[:status]}
        type="select"
        label="Status"
        options={Enum.map(@status_options, fn {v, l} -> {l, to_string(v)} end)}
      />
      <.input
        field={@form[:max_participants]}
        type="number"
        label="Max Participants"
        placeholder="Leave empty for unlimited"
      />
      <div class="md:col-span-2">
        <.input
          field={@form[:prize_description]}
          label="Prize Description"
          placeholder="e.g. 1st place: 3 months free membership"
        />
      </div>
    </div>
    """
  end
end
