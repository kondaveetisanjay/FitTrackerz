defmodule FitconnexWeb.GymOperator.PlansLive do
  use FitconnexWeb, :live_view

  alias FitconnexWeb.AshErrorHelpers

  @durations [
    {:monthly, "1 Month"},
    {:quarterly, "3 Months"},
    {:half_yearly, "6 Months"},
    {:annual, "12 Months"}
  ]

  @plan_type_options [
    {:general, "General"},
    {:personal_training, "Personal Training"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case find_gym(actor) do
      {:ok, gym} ->
        plans = load_plans(gym.id, actor)

        {:ok,
         assign(socket,
           page_title: "Plans & Billing",
           gym: gym,
           plans: plans,
           view: :categories,
           selected_category: nil,
           wizard_step: 1,
           wizard_categories: [""],
           wizard_plan_types: MapSet.new(),
           wizard_prices: %{},
           wizard_errors: [],
           editing_plan_id: nil,
           edit_form: nil,
           durations: @durations,
           plan_type_options: @plan_type_options
         )}

      :no_gym ->
        {:ok,
         assign(socket,
           page_title: "Plans & Billing",
           gym: nil,
           plans: [],
           view: :categories,
           selected_category: nil,
           wizard_step: 1,
           wizard_categories: [""],
           wizard_plan_types: MapSet.new(),
           wizard_prices: %{},
           wizard_errors: [],
           editing_plan_id: nil,
           edit_form: nil,
           durations: @durations,
           plan_type_options: @plan_type_options
         )}
    end
  end

  # ── Navigation Events ──

  @impl true
  def handle_event("create_plans", _params, socket) do
    {:noreply,
     assign(socket,
       view: :wizard,
       wizard_step: 1,
       wizard_categories: [""],
       wizard_plan_types: MapSet.new(),
       wizard_prices: %{},
       wizard_errors: [],
       editing_plan_id: nil,
       edit_form: nil
     )}
  end

  def handle_event("view_category", %{"category" => category}, socket) do
    {:noreply,
     assign(socket,
       view: :detail,
       selected_category: category,
       editing_plan_id: nil,
       edit_form: nil
     )}
  end

  def handle_event("back_to_categories", _params, socket) do
    {:noreply,
     assign(socket,
       view: :categories,
       selected_category: nil,
       editing_plan_id: nil,
       edit_form: nil
     )}
  end

  # ── Wizard Step 1: Categories ──

  def handle_event("add_category_input", _params, socket) do
    categories = socket.assigns.wizard_categories ++ [""]
    {:noreply, assign(socket, wizard_categories: categories, wizard_errors: [])}
  end

  def handle_event("remove_category_input", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    removed = Enum.at(socket.assigns.wizard_categories, index)
    categories = List.delete_at(socket.assigns.wizard_categories, index)
    categories = if categories == [], do: [""], else: categories

    prices =
      socket.assigns.wizard_prices
      |> Enum.reject(fn {{cat, _pt, _dur}, _v} -> cat == removed end)
      |> Map.new()

    {:noreply,
     assign(socket, wizard_categories: categories, wizard_prices: prices, wizard_errors: [])}
  end

  def handle_event("update_category_input", %{"index" => index_str, "value" => value}, socket) do
    index = String.to_integer(index_str)
    old_name = Enum.at(socket.assigns.wizard_categories, index)
    categories = List.replace_at(socket.assigns.wizard_categories, index, value)

    prices =
      if old_name != "" and old_name != value do
        socket.assigns.wizard_prices
        |> Enum.map(fn
          {{^old_name, pt, dur}, v} -> {{value, pt, dur}, v}
          other -> other
        end)
        |> Map.new()
      else
        socket.assigns.wizard_prices
      end

    {:noreply,
     assign(socket, wizard_categories: categories, wizard_prices: prices, wizard_errors: [])}
  end

  # ── Wizard Step 2: Plan Types ──

  def handle_event("toggle_wizard_plan_type", %{"type" => type_str}, socket) do
    type = String.to_existing_atom(type_str)
    current = socket.assigns.wizard_plan_types

    updated =
      if MapSet.member?(current, type),
        do: MapSet.delete(current, type),
        else: MapSet.put(current, type)

    prices =
      socket.assigns.wizard_prices
      |> Enum.filter(fn {{_cat, pt, _dur}, _v} -> MapSet.member?(updated, pt) end)
      |> Map.new()

    {:noreply,
     assign(socket, wizard_plan_types: updated, wizard_prices: prices, wizard_errors: [])}
  end

  # ── Wizard Step 3: Prices ──

  def handle_event(
        "update_wizard_price",
        %{"category" => cat, "type" => type_str, "duration" => dur_str, "value" => value},
        socket
      ) do
    key = {cat, String.to_existing_atom(type_str), String.to_existing_atom(dur_str)}
    prices = Map.put(socket.assigns.wizard_prices, key, value)
    {:noreply, assign(socket, wizard_prices: prices, wizard_errors: [])}
  end

  # ── Wizard Navigation ──

  def handle_event("wizard_next", _params, socket) do
    case socket.assigns.wizard_step do
      1 ->
        categories =
          socket.assigns.wizard_categories
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()

        if categories == [] do
          {:noreply, assign(socket, wizard_errors: ["Enter at least one category name."])}
        else
          {:noreply,
           assign(socket, wizard_step: 2, wizard_categories: categories, wizard_errors: [])}
        end

      2 ->
        if MapSet.size(socket.assigns.wizard_plan_types) == 0 do
          {:noreply, assign(socket, wizard_errors: ["Select at least one plan type."])}
        else
          {:noreply, assign(socket, wizard_step: 3, wizard_errors: [])}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("wizard_back", _params, socket) do
    step = socket.assigns.wizard_step

    if step > 1 do
      {:noreply, assign(socket, wizard_step: step - 1, wizard_errors: [])}
    else
      {:noreply, assign(socket, view: :categories)}
    end
  end

  def handle_event("wizard_done", _params, socket) do
    case validate_wizard(socket.assigns) do
      {:ok, plan_params_list} ->
        actor = socket.assigns.current_user
        gym = socket.assigns.gym

        results =
          Enum.map(plan_params_list, fn params ->
            Fitconnex.Billing.create_plan(Map.put(params, :gym_id, gym.id), actor: actor)
          end)

        errors = Enum.filter(results, &match?({:error, _}, &1))
        plans = load_plans(gym.id, actor)

        if errors == [] do
          {:noreply,
           socket
           |> put_flash(:info, "#{length(plan_params_list)} plan(s) created successfully!")
           |> assign(plans: plans, view: :categories)}
        else
          success_count = length(results) - length(errors)

          {:noreply,
           socket
           |> put_flash(
             :error,
             "#{length(errors)} plan(s) failed. #{success_count} created."
           )
           |> assign(plans: plans, view: :categories)}
        end

      {:error, errors} ->
        {:noreply, assign(socket, wizard_errors: errors)}
    end
  end

  # ── Plan Edit / Delete Events ──

  def handle_event("edit_plan", %{"id" => id}, socket) do
    plan = Enum.find(socket.assigns.plans, &(&1.id == id))

    if plan do
      edit_form =
        to_form(
          %{
            "name" => plan.name || "",
            "plan_type" => to_string(plan.plan_type),
            "duration" => to_string(plan.duration),
            "price_in_rupees" => to_string(div(plan.price_in_paise, 100)),
            "category" => plan.category || ""
          },
          as: "plan"
        )

      {:noreply, assign(socket, editing_plan_id: id, edit_form: edit_form)}
    else
      {:noreply, put_flash(socket, :error, "Plan not found.")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_plan_id: nil, edit_form: nil)}
  end

  def handle_event("validate", %{"plan" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("update_plan", %{"plan" => params}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym
    plan_id = socket.assigns.editing_plan_id

    plan = Enum.find(socket.assigns.plans, &(&1.id == plan_id))

    if plan do
      category =
        case String.trim(params["category"] || "") do
          "" -> nil
          val -> val
        end

      update_params = %{
        name: params["name"],
        plan_type: String.to_existing_atom(params["plan_type"]),
        duration: String.to_existing_atom(params["duration"]),
        price_in_paise: rupees_to_paise(params["price_in_rupees"]),
        category: category
      }

      case Fitconnex.Billing.update_plan(plan, update_params, actor: actor) do
        {:ok, _updated} ->
          plans = load_plans(gym.id, actor)

          {:noreply,
           socket
           |> put_flash(:info, "Plan updated successfully!")
           |> assign(plans: plans, editing_plan_id: nil, edit_form: nil)}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    else
      {:noreply, put_flash(socket, :error, "Plan not found.")}
    end
  end

  def handle_event("delete_plan", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    plan = Enum.find(socket.assigns.plans, &(&1.id == id))

    if plan do
      case Fitconnex.Billing.destroy_plan(plan, actor: actor) do
        :ok ->
          plans = load_plans(gym.id, actor)

          socket =
            if socket.assigns.view == :detail do
              remaining =
                Enum.filter(plans, &(&1.category == socket.assigns.selected_category))

              if remaining == [] do
                assign(socket, view: :categories, selected_category: nil)
              else
                socket
              end
            else
              socket
            end

          {:noreply,
           socket
           |> put_flash(:info, "Plan deleted.")
           |> assign(plans: plans)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete plan.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Plan not found.")}
    end
  end

  # ── Helpers ──

  defp validate_wizard(assigns) do
    categories =
      assigns.wizard_categories
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    plan_types = MapSet.to_list(assigns.wizard_plan_types)

    errors = []
    errors = if categories == [], do: ["Enter at least one category." | errors], else: errors

    errors =
      if plan_types == [], do: ["Select at least one plan type." | errors], else: errors

    expected_keys =
      for cat <- categories,
          pt <- plan_types,
          {dur, _label} <- @durations,
          do: {cat, pt, dur}

    missing =
      Enum.filter(expected_keys, fn key ->
        val = Map.get(assigns.wizard_prices, key, "")
        val == "" or val == nil
      end)

    errors =
      if missing != [],
        do: ["Fill in all price fields (#{length(missing)} missing)." | errors],
        else: errors

    if errors == [] do
      plans =
        Enum.map(expected_keys, fn {cat, pt, dur} = key ->
          price_str = Map.get(assigns.wizard_prices, key)
          name = build_plan_name(cat, pt, dur, price_str)

          %{
            name: name,
            category: cat,
            plan_type: pt,
            duration: dur,
            price_in_paise: rupees_to_paise(price_str)
          }
        end)

      {:ok, plans}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp build_plan_name(category, plan_type, duration, price_str) do
    cat = category || "N/A"
    pt = format_plan_type(plan_type)
    dur = format_duration(duration)
    "#{cat} - #{pt} - #{dur} - \u20B9#{price_str}"
  end

  defp find_gym(actor) do
    case Fitconnex.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} -> {:ok, gym}
      _ -> :no_gym
    end
  end

  defp load_plans(gym_id, actor) do
    case Fitconnex.Billing.list_plans_by_gym(gym_id, actor: actor) do
      {:ok, plans} -> plans
      _ -> []
    end
  end

  defp group_plans_by_category(plans) do
    plans
    |> Enum.group_by(&(&1.category || "Uncategorized"))
    |> Enum.sort_by(fn {cat, _} -> cat end)
  end

  defp plans_by_type(plans, type) do
    duration_order = [:day_pass, :monthly, :quarterly, :half_yearly, :annual, :two_year]

    plans
    |> Enum.filter(&(&1.plan_type == type))
    |> Enum.sort_by(fn p ->
      Enum.find_index(duration_order, &(&1 == p.duration)) || 99
    end)
  end

  defp rupees_to_paise(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> round(f * 100)
      :error -> 0
    end
  end

  defp rupees_to_paise(_), do: 0

  defp format_price(paise) when is_integer(paise) do
    Integer.to_string(div(paise, 100))
  end

  defp format_price(_), do: "0"

  defp format_duration(:day_pass), do: "1 Day Pass"
  defp format_duration(:monthly), do: "1 Month"
  defp format_duration(:quarterly), do: "3 Months"
  defp format_duration(:half_yearly), do: "6 Months"
  defp format_duration(:annual), do: "12 Months"
  defp format_duration(:two_year), do: "24 Months"
  defp format_duration(other), do: Phoenix.Naming.humanize(other)

  defp format_plan_type(:general), do: "General"
  defp format_plan_type(:personal_training), do: "Personal Training"
  defp format_plan_type(other), do: Phoenix.Naming.humanize(other)

  defp category_icon_bg(cat) do
    colors = [
      "bg-primary/20 text-primary",
      "bg-secondary/20 text-secondary",
      "bg-accent/20 text-accent",
      "bg-info/20 text-info",
      "bg-success/20 text-success",
      "bg-warning/20 text-warning"
    ]

    index = :erlang.phash2(cat, length(colors))
    Enum.at(colors, index)
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex items-center gap-3">
          <%= if @view == :detail do %>
            <button
              phx-click="back_to_categories"
              class="btn btn-ghost btn-sm btn-circle"
              id="back-to-cats"
            >
              <.icon name="hero-arrow-left" class="size-5" />
            </button>
          <% else %>
            <Layouts.back_button />
          <% end %>
          <div>
            <h1 class="text-2xl sm:text-3xl font-black tracking-tight">
              <%= case @view do %>
                <% :detail -> %>
                  {@selected_category}
                <% :wizard -> %>
                  Create Plans
                <% _ -> %>
                  Plans & Billing
              <% end %>
            </h1>
            <p class="text-base-content/50 mt-1">
              <%= case @view do %>
                <% :detail -> %>
                  View and manage plans in this category.
                <% :wizard -> %>
                  Step {@wizard_step} of 3
                <% _ -> %>
                  Manage subscription plans for your gym.
              <% end %>
            </p>
          </div>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon
                name="hero-building-office-solid"
                class="size-12 text-base-content/20 mx-auto"
              />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before managing plans.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%= case @view do %>
            <% :categories -> %>
              {render_categories(assigns)}
            <% :wizard -> %>
              {render_wizard(assigns)}
            <% :detail -> %>
              {render_detail(assigns)}
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ── Categories Landing View ──

  defp render_categories(assigns) do
    grouped = group_plans_by_category(assigns.plans)
    assigns = assign(assigns, :grouped, grouped)

    ~H"""
    <%= if @plans == [] do %>
      <div class="flex flex-col items-center justify-center py-20" id="no-plans">
        <.icon name="hero-credit-card-solid" class="size-16 text-base-content/15 mb-6" />
        <h2 class="text-xl font-bold text-base-content/60 mb-2">No Plans Yet</h2>
        <p class="text-base-content/40 mb-8 text-center max-w-md">
          Create subscription plans so members can sign up for your gym.
        </p>
        <button phx-click="create_plans" class="btn btn-primary gap-2" id="create-plans-btn">
          <.icon name="hero-plus-mini" class="size-5" /> Create Plans
        </button>
      </div>
    <% else %>
      <div class="flex justify-end mb-2">
        <button
          phx-click="create_plans"
          class="btn btn-primary btn-sm gap-2"
          id="create-plans-btn"
        >
          <.icon name="hero-plus-mini" class="size-4" /> Create Plans
        </button>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="category-grid">
        <div
          :for={{category, cat_plans} <- @grouped}
          class="card bg-base-200/50 border border-base-300/50 hover:border-primary/30 hover:shadow-lg cursor-pointer transition-all"
          phx-click="view_category"
          phx-value-category={category}
          id={"cat-#{category}"}
        >
          <div class="card-body p-5">
            <div class="flex items-center gap-3">
              <div class={"size-10 rounded-lg flex items-center justify-center #{category_icon_bg(category)}"}>
                <.icon name="hero-tag-solid" class="size-5" />
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="text-lg font-bold truncate">{category}</h3>
                <p class="text-sm text-base-content/50">
                  {length(cat_plans)} plan(s)
                </p>
              </div>
              <.icon name="hero-chevron-right" class="size-5 text-base-content/30 shrink-0" />
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ── Wizard View ──

  defp render_wizard(assigns) do
    ~H"""
    <div class="card bg-base-200/50 border border-base-300/50" id="wizard-card">
      <div class="card-body p-6">
        <%!-- Progress Steps --%>
        <ul class="steps steps-horizontal w-full mb-8">
          <li class={"step #{if @wizard_step >= 1, do: "step-primary"}"}>Categories</li>
          <li class={"step #{if @wizard_step >= 2, do: "step-primary"}"}>Plan Types</li>
          <li class={"step #{if @wizard_step >= 3, do: "step-primary"}"}>Pricing</li>
        </ul>

        <%!-- Errors --%>
        <%= if @wizard_errors != [] do %>
          <div class="alert alert-error mb-6" id="wizard-errors">
            <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
            <div>
              <p :for={err <- @wizard_errors} class="text-sm">{err}</p>
            </div>
          </div>
        <% end %>

        <%= case @wizard_step do %>
          <% 1 -> %>
            {render_wizard_step1(assigns)}
          <% 2 -> %>
            {render_wizard_step2(assigns)}
          <% 3 -> %>
            {render_wizard_step3(assigns)}
        <% end %>
      </div>
    </div>
    """
  end

  defp render_wizard_step1(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-bold mb-1">What categories do you offer?</h2>
      <p class="text-base-content/50 text-sm mb-6">
        Enter the training categories at your gym (e.g. Cross Fit, Gym, Yoga, Calisthenics).
      </p>

      <div class="space-y-3 max-w-md">
        <div
          :for={{cat, index} <- Enum.with_index(@wizard_categories)}
          class="flex items-center gap-2"
          id={"wiz-cat-row-#{index}"}
        >
          <input
            type="text"
            placeholder={"Category #{index + 1}"}
            class="input input-bordered input-sm flex-1"
            value={cat}
            phx-blur="update_category_input"
            phx-keyup="update_category_input"
            phx-debounce="300"
            phx-value-index={index}
            id={"wiz-cat-input-#{index}"}
          />
          <%= if length(@wizard_categories) > 1 do %>
            <button
              phx-click="remove_category_input"
              phx-value-index={index}
              class="btn btn-ghost btn-sm btn-circle text-error"
              id={"wiz-cat-remove-#{index}"}
            >
              <.icon name="hero-x-mark-mini" class="size-4" />
            </button>
          <% end %>
        </div>
      </div>

      <button
        phx-click="add_category_input"
        class="btn btn-ghost btn-sm gap-1 mt-3 text-primary"
        id="wiz-add-category"
      >
        <.icon name="hero-plus-mini" class="size-4" /> Add another category
      </button>

      <div class="flex justify-between mt-8">
        <button phx-click="wizard_back" class="btn btn-ghost btn-sm" id="wiz-back-1">
          Cancel
        </button>
        <button phx-click="wizard_next" class="btn btn-primary btn-sm gap-1" id="wiz-next-1">
          Next <.icon name="hero-arrow-right-mini" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  defp render_wizard_step2(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-bold mb-1">Select Plan Types</h2>
      <p class="text-base-content/50 text-sm mb-6">
        Choose which plan types you want to offer.
      </p>

      <div class="space-y-4 max-w-md">
        <label
          :for={{value, label} <- @plan_type_options}
          class={"flex items-center gap-3 p-4 rounded-xl border cursor-pointer transition-all #{if MapSet.member?(@wizard_plan_types, value), do: "bg-primary/5 border-primary/30", else: "bg-base-300/10 border-base-300/30"}"}
          id={"wiz-type-#{value}"}
        >
          <input
            type="checkbox"
            class="checkbox checkbox-sm checkbox-primary"
            checked={MapSet.member?(@wizard_plan_types, value)}
            phx-click="toggle_wizard_plan_type"
            phx-value-type={value}
          />
          <div>
            <span class="font-semibold">{label}</span>
            <p class="text-xs text-base-content/50 mt-0.5">
              <%= if value == :general do %>
                Standard gym membership with access to facilities.
              <% else %>
                One-on-one training sessions with a personal trainer.
              <% end %>
            </p>
          </div>
        </label>
      </div>

      <div class="flex justify-between mt-8">
        <button phx-click="wizard_back" class="btn btn-ghost btn-sm gap-1" id="wiz-back-2">
          <.icon name="hero-arrow-left-mini" class="size-4" /> Back
        </button>
        <button phx-click="wizard_next" class="btn btn-primary btn-sm gap-1" id="wiz-next-2">
          Next <.icon name="hero-arrow-right-mini" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  defp render_wizard_step3(assigns) do
    categories =
      assigns.wizard_categories
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    selected_types =
      Enum.filter(@plan_type_options, fn {v, _} ->
        MapSet.member?(assigns.wizard_plan_types, v)
      end)

    total_plans = length(categories) * length(selected_types) * length(@durations)

    assigns =
      assign(assigns,
        wiz_categories: categories,
        wiz_selected_types: selected_types,
        wiz_total_plans: total_plans
      )

    ~H"""
    <div>
      <h2 class="text-lg font-bold mb-1">Set Prices</h2>
      <p class="text-base-content/50 text-sm mb-6">
        Enter the price (in &#8377;) for each combination.
      </p>

      <div class="space-y-8">
        <div :for={cat <- @wiz_categories} id={"wiz-price-cat-#{cat}"}>
          <h3 class="text-md font-bold mb-3 flex items-center gap-2">
            <.icon name="hero-tag-solid" class="size-4 text-primary" />
            {cat}
          </h3>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr class="text-base-content/40 text-xs">
                  <th>Duration</th>
                  <th :for={{_v, label} <- @wiz_selected_types}>{label} (&#8377;)</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={{dur_value, dur_label} <- @durations}
                  id={"wiz-price-#{cat}-#{dur_value}"}
                >
                  <td class="font-medium text-sm">{dur_label}</td>
                  <td :for={{pt_value, _pt_label} <- @wiz_selected_types}>
                    <input
                      type="number"
                      min="1"
                      placeholder="Price"
                      class="input input-bordered input-sm w-28"
                      value={Map.get(@wizard_prices, {cat, pt_value, dur_value}, "")}
                      phx-blur="update_wizard_price"
                      phx-value-category={cat}
                      phx-value-type={pt_value}
                      phx-value-duration={dur_value}
                      id={"wiz-price-input-#{cat}-#{pt_value}-#{dur_value}"}
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="flex justify-between mt-8">
        <button phx-click="wizard_back" class="btn btn-ghost btn-sm gap-1" id="wiz-back-3">
          <.icon name="hero-arrow-left-mini" class="size-4" /> Back
        </button>
        <button phx-click="wizard_done" class="btn btn-primary btn-sm gap-2" id="wiz-done">
          <.icon name="hero-check-mini" class="size-4" /> Create {@wiz_total_plans} Plan(s)
        </button>
      </div>
    </div>
    """
  end

  # ── Category Detail View ──

  defp render_detail(assigns) do
    cat_plans =
      Enum.filter(assigns.plans, &(&1.category == assigns.selected_category))

    general_plans = plans_by_type(cat_plans, :general)
    pt_plans = plans_by_type(cat_plans, :personal_training)

    assigns =
      assign(assigns,
        general_plans: general_plans,
        pt_plans: pt_plans,
        has_general: general_plans != [],
        has_pt: pt_plans != []
      )

    ~H"""
    <%!-- Edit Form --%>
    <%= if @editing_plan_id do %>
      <div class="card bg-base-200/50 border border-base-300/50 mb-6" id="edit-plan-card">
        <div class="card-body p-6">
          <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
            <.icon name="hero-pencil-square-solid" class="size-5 text-info" /> Edit Plan
          </h2>
          <.form
            for={@edit_form}
            id="edit-plan-form"
            phx-change="validate"
            phx-submit="update_plan"
          >
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input field={@edit_form[:name]} label="Plan Name" required />
              <.input field={@edit_form[:category]} label="Category" />
              <.input
                field={@edit_form[:plan_type]}
                type="select"
                label="Plan Type"
                prompt="Select plan type"
                options={[
                  {"General", "general"},
                  {"Personal Training", "personal_training"}
                ]}
                required
              />
              <.input
                field={@edit_form[:duration]}
                type="select"
                label="Duration"
                prompt="Select duration"
                options={[
                  {"1 Day Pass", "day_pass"},
                  {"1 Month", "monthly"},
                  {"3 Months", "quarterly"},
                  {"6 Months", "half_yearly"},
                  {"12 Months", "annual"},
                  {"24 Months", "two_year"}
                ]}
                required
              />
              <.input
                field={@edit_form[:price_in_rupees]}
                type="number"
                label="Price (in Rupees)"
                required
              />
            </div>
            <div class="flex gap-2 mt-4">
              <button type="submit" class="btn btn-primary btn-sm gap-2" id="update-plan-btn">
                <.icon name="hero-check-mini" class="size-4" /> Update
              </button>
              <button
                type="button"
                phx-click="cancel_edit"
                class="btn btn-ghost btn-sm"
                id="cancel-edit-btn"
              >
                Cancel
              </button>
            </div>
          </.form>
        </div>
      </div>
    <% end %>

    <%!-- Side-by-side Plan Types --%>
    <div
      class={"grid gap-6 #{if @has_general and @has_pt, do: "grid-cols-1 md:grid-cols-2", else: "grid-cols-1 max-w-lg"}"}
      id="detail-grid"
    >
      <%!-- General Plans --%>
      <%= if @has_general do %>
        <div class="card bg-base-200/50 border border-base-300/50" id="general-plans">
          <div class="card-body p-5">
            <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
              <span class="badge badge-primary badge-sm">General</span>
            </h2>
            <div class="space-y-3">
              <div
                :for={plan <- @general_plans}
                class="flex items-center justify-between p-3 rounded-lg bg-base-300/20"
                id={"detail-plan-#{plan.id}"}
              >
                <p class="font-semibold text-sm">{format_duration(plan.duration)}</p>
                <div class="flex items-center gap-2">
                  <span class="font-black text-primary text-lg">
                    &#8377;{format_price(plan.price_in_paise)}
                  </span>
                  <div class="flex gap-0.5">
                    <button
                      phx-click="edit_plan"
                      phx-value-id={plan.id}
                      class="btn btn-ghost btn-xs text-info"
                      id={"edit-#{plan.id}"}
                    >
                      <.icon name="hero-pencil-square" class="size-3.5" />
                    </button>
                    <button
                      phx-click="delete_plan"
                      phx-value-id={plan.id}
                      data-confirm="Delete this plan?"
                      class="btn btn-ghost btn-xs text-error"
                      id={"delete-#{plan.id}"}
                    >
                      <.icon name="hero-trash" class="size-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Personal Training Plans --%>
      <%= if @has_pt do %>
        <div class="card bg-base-200/50 border border-base-300/50" id="pt-plans">
          <div class="card-body p-5">
            <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
              <span class="badge badge-secondary badge-sm">Personal Training</span>
            </h2>
            <div class="space-y-3">
              <div
                :for={plan <- @pt_plans}
                class="flex items-center justify-between p-3 rounded-lg bg-base-300/20"
                id={"detail-plan-#{plan.id}"}
              >
                <p class="font-semibold text-sm">{format_duration(plan.duration)}</p>
                <div class="flex items-center gap-2">
                  <span class="font-black text-primary text-lg">
                    &#8377;{format_price(plan.price_in_paise)}
                  </span>
                  <div class="flex gap-0.5">
                    <button
                      phx-click="edit_plan"
                      phx-value-id={plan.id}
                      class="btn btn-ghost btn-xs text-info"
                      id={"edit-#{plan.id}"}
                    >
                      <.icon name="hero-pencil-square" class="size-3.5" />
                    </button>
                    <button
                      phx-click="delete_plan"
                      phx-value-id={plan.id}
                      data-confirm="Delete this plan?"
                      class="btn btn-ghost btn-xs text-error"
                      id={"delete-#{plan.id}"}
                    >
                      <.icon name="hero-trash" class="size-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
