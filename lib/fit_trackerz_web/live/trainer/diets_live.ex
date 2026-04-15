defmodule FitTrackerzWeb.Trainer.DietsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

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
       |> assign(page_title: "Diet Plans")
       |> assign(no_gym: true, diets: [], clients: [], gyms: [], gym_trainers: [], form: nil, show_form: false)}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)
      trainer_ids = Enum.map(gym_trainers, & &1.id)

      diets = case FitTrackerz.Training.list_diets_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
        {:ok, diets} -> diets
        _ -> []
      end

      clients = case FitTrackerz.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user]) do
        {:ok, members} -> members
        _ -> []
      end

      form =
        to_form(
          %{
            "name" => "",
            "calorie_target" => "",
            "dietary_type" => "",
            "member_id" => "",
            "gym_id" => ""
          },
          as: "diet"
        )

      {:ok,
       socket
       |> assign(page_title: "Diet Plans")
       |> assign(
         no_gym: false,
         diets: diets,
         clients: clients,
         gyms: gyms,
         gym_trainers: gym_trainers,
         form: form,
         show_form: false
       )}
    end
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  @impl true
  def handle_event("validate", %{"diet" => params}, socket) do
    form = to_form(params, as: "diet")
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save_diet", %{"diet" => params}, socket) do
    gym_trainers = socket.assigns.gym_trainers
    trainer_ids = Enum.map(gym_trainers, & &1.id)
    gym_trainer = Enum.find(gym_trainers, &(&1.gym_id == params["gym_id"]))

    calorie_target =
      case Integer.parse(params["calorie_target"] || "") do
        {val, _} -> val
        :error -> nil
      end

    dietary_type =
      case params["dietary_type"] do
        "" -> nil
        val -> String.to_existing_atom(val)
      end

    actor = socket.assigns.current_user

    case FitTrackerz.Training.create_diet(%{
      name: params["name"],
      calorie_target: calorie_target,
      dietary_type: dietary_type,
      member_id: params["member_id"],
      gym_id: params["gym_id"],
      trainer_id: gym_trainer && gym_trainer.id
    }, actor: actor) do
      {:ok, _plan} ->
        diets = case FitTrackerz.Training.list_diets_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
          {:ok, diets} -> diets
          _ -> []
        end

        form =
          to_form(
            %{
              "name" => "",
              "calorie_target" => "",
              "dietary_type" => "",
              "member_id" => "",
              "gym_id" => ""
            },
            as: "diet"
          )

        {:noreply,
         socket
         |> assign(diets: diets, form: form, show_form: false)
         |> put_flash(:info, "Diet plan created successfully.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  @impl true
  def handle_event("delete_diet", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    trainer_ids = Enum.map(socket.assigns.gym_trainers, & &1.id)
    diet = Enum.find(socket.assigns.diets, &(&1.id == id))

    if diet do
      case FitTrackerz.Training.destroy_diet(diet, actor: actor) do
        :ok ->
          diets = case FitTrackerz.Training.list_diets_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
            {:ok, diets} -> diets
            _ -> []
          end

          {:noreply,
           socket
           |> assign(diets: diets)
           |> put_flash(:info, "Diet plan deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete diet plan.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Diet plan not found.")}
    end
  end

  defp dietary_type_badge_class(type) do
    case type do
      :vegetarian -> "badge-success"
      :vegan -> "badge-primary"
      :eggetarian -> "badge-warning"
      :non_vegetarian -> "badge-error"
      _ -> "badge-ghost"
    end
  end

  defp format_dietary_type(type) do
    case type do
      :vegetarian -> "Vegetarian"
      :non_vegetarian -> "Non-Vegetarian"
      :vegan -> "Vegan"
      :eggetarian -> "Eggetarian"
      _ -> "N/A"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Diet Plans" subtitle="Create and manage diet plans for your clients." back_path="/trainer">
        <:actions>
          <%= unless @no_gym do %>
            <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form" id="toggle-diet-form-btn">
              New Diet Plan
            </.button>
          <% end %>
        </:actions>
      </.page_header>

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-exclamation-triangle"
          title="No Gym Association"
          subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%!-- Create Form --%>
        <%= if @show_form do %>
          <div class="mb-8">
            <.card title="New Diet Plan">
              <.form
                for={@form}
                id="diet-form"
                phx-change="validate"
                phx-submit="save_diet"
                class="space-y-4"
              >
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div>
                    <label class="label"><span class="label-text font-medium">Plan Name</span></label>
                    <input
                      type="text"
                      name="diet[name]"
                      id="diet_name"
                      value={@form[:name].value || ""}
                      placeholder="e.g., High Protein Plan"
                      class="w-full input"
                    />
                  </div>
                  <div>
                    <label class="label"><span class="label-text font-medium">Calorie Target</span></label>
                    <input
                      type="number"
                      name="diet[calorie_target]"
                      id="diet_calorie_target"
                      value={@form[:calorie_target].value || ""}
                      placeholder="2000"
                      class="w-full input"
                    />
                  </div>
                  <div>
                    <label class="label">
                      <span class="label-text font-medium">Dietary Type</span>
                    </label>
                    <select
                      name="diet[dietary_type]"
                      class="select select-bordered w-full"
                      id="diet-type-select"
                    >
                      <option value="" selected={@form[:dietary_type].value in [nil, ""]}>Select type...</option>
                      <option value="vegetarian" selected={to_string(@form[:dietary_type].value) == "vegetarian"}>Vegetarian</option>
                      <option value="non_vegetarian" selected={to_string(@form[:dietary_type].value) == "non_vegetarian"}>Non-Vegetarian</option>
                      <option value="vegan" selected={to_string(@form[:dietary_type].value) == "vegan"}>Vegan</option>
                      <option value="eggetarian" selected={to_string(@form[:dietary_type].value) == "eggetarian"}>Eggetarian</option>
                    </select>
                  </div>
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label class="label"><span class="label-text font-medium">Client</span></label>
                    <select
                      name="diet[member_id]"
                      class="select select-bordered w-full"
                      id="diet-member-select"
                    >
                      <option value="" selected={@form[:member_id].value in [nil, ""]}>Select a client...</option>
                      <option
                        :for={client <- @clients}
                        value={client.id}
                        selected={@form[:member_id].value == client.id}
                      >
                        {client.user.name}
                      </option>
                    </select>
                  </div>
                  <div>
                    <label class="label"><span class="label-text font-medium">Gym</span></label>
                    <select
                      name="diet[gym_id]"
                      class="select select-bordered w-full"
                      id="diet-gym-select"
                    >
                      <option value="" selected={@form[:gym_id].value in [nil, ""]}>Select a gym...</option>
                      <option
                        :for={gym <- @gyms}
                        value={gym.id}
                        selected={@form[:gym_id].value == gym.id}
                      >
                        {gym.name}
                      </option>
                    </select>
                  </div>
                </div>
                <div class="flex justify-end gap-2 pt-2">
                  <.button type="button" variant="ghost" size="sm" phx-click="toggle_form" id="cancel-diet-btn">
                    Cancel
                  </.button>
                  <.button type="submit" variant="primary" size="sm" icon="hero-check" id="submit-diet-btn">
                    Create Plan
                  </.button>
                </div>
              </.form>
            </.card>
          </div>
        <% end %>

        <%!-- Diet Plans --%>
        <%= if @diets == [] do %>
          <.empty_state
            icon="hero-heart"
            title="No Diet Plans Yet"
            subtitle="Create your first diet plan to help your clients with their nutrition."
          >
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form">
                Create Diet Plan
              </.button>
            </:action>
          </.empty_state>
        <% else %>
          <.data_table id="diets-table" rows={@diets} row_id={fn d -> "diet-#{d.id}" end}>
            <:col :let={diet} label="Plan Name">
              <span class="font-bold">{diet.name}</span>
            </:col>
            <:col :let={diet} label="Client">
              <div class="flex items-center gap-2">
                <%= if diet.member do %>
                  <.avatar name={diet.member.user.name} size="sm" />
                  <span>{diet.member.user.name}</span>
                <% else %>
                  <span class="text-base-content/40">Unassigned</span>
                <% end %>
              </div>
            </:col>
            <:col :let={diet} label="Gym">
              {if diet.gym, do: diet.gym.name, else: "N/A"}
            </:col>
            <:col :let={diet} label="Calories">
              {if diet.calorie_target, do: "#{diet.calorie_target} kcal", else: "--"}
            </:col>
            <:col :let={diet} label="Type">
              <%= if diet.dietary_type do %>
                <span class={"badge badge-sm #{dietary_type_badge_class(diet.dietary_type)}"}>
                  {format_dietary_type(diet.dietary_type)}
                </span>
              <% else %>
                <span class="text-base-content/40">--</span>
              <% end %>
            </:col>
            <:actions :let={diet}>
              <.button
                variant="danger"
                size="sm"
                icon="hero-trash"
                phx-click="delete_diet"
                phx-value-id={diet.id}
                data-confirm="Are you sure you want to delete this diet plan?"
              >
                <span class="sr-only">Delete</span>
              </.button>
            </:actions>
            <:mobile_card :let={diet}>
              <div>
                <p class="font-bold">{diet.name}</p>
                <p class="text-xs text-base-content/50 mt-1">
                  {if diet.member, do: diet.member.user.name, else: "Unassigned"}
                  <%= if diet.dietary_type do %>
                    &middot; {format_dietary_type(diet.dietary_type)}
                  <% end %>
                </p>
              </div>
            </:mobile_card>
          </.data_table>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
