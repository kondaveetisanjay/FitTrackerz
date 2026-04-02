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

  defp type_badge_class(:challenge), do: "badge-warning"
  defp type_badge_class(:competition), do: "badge-error"
  defp type_badge_class(:event), do: "badge-info"
  defp type_badge_class(_), do: "badge-ghost"

  defp status_badge_class(:upcoming), do: "badge-info"
  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:completed), do: "badge-ghost"
  defp status_badge_class(:cancelled), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">Contests</h1>
              <p class="text-base-content/50 mt-1">
                Create and manage fitness contests for your gym.
              </p>
            </div>
          </div>
        </div>

        <%= if @gym == nil do %>
          <div class="ft-card p-6" id="no-gym-card">
            <div class="text-center">
              <.icon
                name="hero-building-office-solid"
                class="size-12 text-base-content/20 mx-auto"
              />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before managing contests.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Create Button --%>
          <div class="flex justify-end">
            <button
              phx-click="toggle_form"
              class="btn btn-primary btn-sm gap-2 press-scale"
              id="toggle-contest-form"
            >
              <.icon name="hero-plus-mini" class="size-4" /> New Contest
            </button>
          </div>

          <%!-- Create Form --%>
          <%= if @show_form do %>
            <div class="ft-card p-6" id="create-contest-card">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-trophy-solid" class="size-5 text-primary" /> New Contest
              </h2>
              <.form
                for={@form}
                id="create-contest-form"
                phx-change="validate"
                phx-submit="save_contest"
              >
                {render_contest_fields(assigns)}
                <div class="flex gap-2 mt-4">
                  <button type="submit" class="btn btn-primary btn-sm gap-2" id="save-contest-btn">
                    <.icon name="hero-check-mini" class="size-4" /> Create Contest
                  </button>
                  <button
                    type="button"
                    phx-click="toggle_form"
                    class="btn btn-ghost btn-sm press-scale"
                    id="cancel-create-btn"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          <% end %>

          <%!-- Edit Form --%>
          <%= if @editing_contest_id do %>
            <div class="ft-card p-6" id="edit-contest-card">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-pencil-square-solid" class="size-5 text-info" /> Edit Contest
              </h2>
              <.form
                for={@form}
                id="edit-contest-form"
                phx-change="validate"
                phx-submit="update_contest"
              >
                {render_contest_fields(assigns)}
                <div class="flex gap-2 mt-4">
                  <button
                    type="submit"
                    class="btn btn-primary btn-sm gap-2"
                    id="update-contest-btn"
                  >
                    <.icon name="hero-check-mini" class="size-4" /> Update
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_edit"
                    class="btn btn-ghost btn-sm press-scale"
                    id="cancel-edit-btn"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          <% end %>

          <%!-- Contest List --%>
          <%= if @contests == [] do %>
            <div class="flex flex-col items-center justify-center py-20" id="no-contests">
              <.icon name="hero-trophy-solid" class="size-16 text-base-content/15 mb-6" />
              <h2 class="text-xl font-bold text-base-content/60 mb-2">No Contests Yet</h2>
              <p class="text-base-content/40 mb-8 text-center max-w-md">
                Create fitness contests to engage your members with challenges, competitions, and events.
              </p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="contests-grid">
              <%= for contest <- @contests do %>
                <div
                  class="ft-card overflow-hidden"
                  id={"contest-#{contest.id}"}
                >
                  <div class="p-4 space-y-3">
                    <%!-- Badges --%>
                    <div class="flex flex-wrap gap-1.5">
                      <span class={"badge badge-sm #{type_badge_class(contest.contest_type)}"}>
                        {contest.contest_type |> to_string() |> String.capitalize()}
                      </span>
                      <span class={"badge badge-sm #{status_badge_class(contest.status)}"}>
                        {contest.status |> to_string() |> String.capitalize()}
                      </span>
                    </div>

                    <%!-- Title --%>
                    <h3 class="card-title text-base leading-tight">{contest.title}</h3>

                    <%!-- Description --%>
                    <%= if contest.description do %>
                      <p class="text-sm text-base-content/60 line-clamp-2">
                        {contest.description}
                      </p>
                    <% end %>

                    <%!-- Dates --%>
                    <div class="flex items-center gap-1.5 text-sm text-base-content/60">
                      <.icon name="hero-calendar-mini" class="size-3.5 shrink-0" />
                      <span>
                        {format_date(contest.starts_at)} — {format_date(contest.ends_at)}
                      </span>
                    </div>

                    <%!-- Participants --%>
                    <%= if contest.max_participants do %>
                      <div class="flex items-center gap-1.5 text-sm text-base-content/60">
                        <.icon name="hero-users-mini" class="size-3.5 shrink-0" />
                        <span>{contest.max_participants} max participants</span>
                      </div>
                    <% end %>

                    <%!-- Prize --%>
                    <%= if contest.prize_description do %>
                      <div class="flex items-start gap-1.5 text-sm text-base-content/60">
                        <.icon name="hero-gift-mini" class="size-3.5 shrink-0 mt-0.5" />
                        <span class="line-clamp-1">{contest.prize_description}</span>
                      </div>
                    <% end %>

                    <%!-- Actions --%>
                    <div class="flex gap-2 mt-auto pt-2 border-t border-base-200/50">
                      <button
                        phx-click="edit_contest"
                        phx-value-id={contest.id}
                        class="btn btn-ghost btn-xs text-info gap-1 press-scale"
                        id={"edit-#{contest.id}"}
                      >
                        <.icon name="hero-pencil-square" class="size-3.5" /> Edit
                      </button>
                      <button
                        phx-click="delete_contest"
                        phx-value-id={contest.id}
                        data-confirm="Are you sure you want to delete this contest?"
                        class="btn btn-ghost btn-xs text-error gap-1 press-scale"
                        id={"delete-#{contest.id}"}
                      >
                        <.icon name="hero-trash" class="size-3.5" /> Delete
                      </button>
                    </div>
                  </div>
                </div>
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
      <.input field={@form[:title]} label="Title" placeholder="e.g. 30-Day Weight Loss Challenge" required />
      <.input
        field={@form[:contest_type]}
        type="select"
        label="Contest Type"
        options={Enum.map(@contest_types, fn {v, l} -> {l, to_string(v)} end)}
        required
      />
      <div class="md:col-span-2">
        <.input
          field={@form[:description]}
          type="textarea"
          label="Description"
          placeholder="Describe the contest rules, goals, and how participants can join..."
        />
      </div>
      <.input field={@form[:starts_at]} type="datetime-local" label="Start Date" required />
      <.input field={@form[:ends_at]} type="datetime-local" label="End Date" required />
      <.input
        field={@form[:status]}
        type="select"
        label="Status"
        options={Enum.map(@status_options, fn {v, l} -> {l, to_string(v)} end)}
        required
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
