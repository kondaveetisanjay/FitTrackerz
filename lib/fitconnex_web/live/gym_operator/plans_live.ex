defmodule FitconnexWeb.GymOperator.PlansLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    case find_gym(user.id) do
      {:ok, gym} ->
        gid = gym.id

        plans =
          Fitconnex.Billing.SubscriptionPlan
          |> Ash.Query.filter(gym_id == ^gid)
          |> Ash.read!()

        form =
          to_form(
            %{
              "name" => "",
              "plan_type" => "",
              "duration" => "",
              "price_in_rupees" => ""
            },
            as: "plan"
          )

        {:ok,
         assign(socket,
           page_title: "Plans & Billing",
           gym: gym,
           plans: plans,
           form: form,
           show_form: false,
           editing_plan_id: nil,
           edit_form: nil
         )}

      :no_gym ->
        {:ok,
         assign(socket,
           page_title: "Plans & Billing",
           gym: nil,
           plans: [],
           form: nil,
           show_form: false,
           editing_plan_id: nil,
           edit_form: nil
         )}
    end
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  def handle_event("validate", %{"plan" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save_plan", %{"plan" => params}, socket) do
    gym = socket.assigns.gym
    gid = gym.id

    case Fitconnex.Billing.SubscriptionPlan
         |> Ash.Changeset.for_create(:create, %{
           name: params["name"],
           plan_type: String.to_existing_atom(params["plan_type"]),
           duration: String.to_existing_atom(params["duration"]),
           price_in_paise: rupees_to_paise(params["price_in_rupees"]),
           gym_id: gym.id
         })
         |> Ash.create() do
      {:ok, _plan} ->
        plans =
          Fitconnex.Billing.SubscriptionPlan
          |> Ash.Query.filter(gym_id == ^gid)
          |> Ash.read!()

        form =
          to_form(
            %{
              "name" => "",
              "plan_type" => "",
              "duration" => "",
              "price_in_rupees" => ""
            },
            as: "plan"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Subscription plan created successfully!")
         |> assign(plans: plans, form: form, show_form: false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create plan. Please check your input.")}
    end
  end

  def handle_event("edit_plan", %{"id" => id}, socket) do
    gym = socket.assigns.gym
    gid = gym.id

    plan =
      Fitconnex.Billing.SubscriptionPlan
      |> Ash.Query.filter(id == ^id and gym_id == ^gid)
      |> Ash.read!()
      |> List.first()

    if plan do
      edit_form =
        to_form(
          %{
            "name" => plan.name || "",
            "plan_type" => to_string(plan.plan_type),
            "duration" => to_string(plan.duration),
            "price_in_rupees" => to_string(div(plan.price_in_paise, 100))
          },
          as: "plan"
        )

      {:noreply, assign(socket, editing_plan_id: id, edit_form: edit_form, show_form: false)}
    else
      {:noreply, put_flash(socket, :error, "Plan not found.")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_plan_id: nil, edit_form: nil)}
  end

  def handle_event("update_plan", %{"plan" => params}, socket) do
    gym = socket.assigns.gym
    gid = gym.id
    plan_id = socket.assigns.editing_plan_id

    plan =
      Fitconnex.Billing.SubscriptionPlan
      |> Ash.Query.filter(id == ^plan_id and gym_id == ^gid)
      |> Ash.read!()
      |> List.first()

    if plan do
      update_params = %{
        name: params["name"],
        plan_type: String.to_existing_atom(params["plan_type"]),
        duration: String.to_existing_atom(params["duration"]),
        price_in_paise: rupees_to_paise(params["price_in_rupees"])
      }

      case plan
           |> Ash.Changeset.for_update(:update, update_params)
           |> Ash.update() do
        {:ok, _updated} ->
          plans =
            Fitconnex.Billing.SubscriptionPlan
            |> Ash.Query.filter(gym_id == ^gid)
            |> Ash.read!()

          {:noreply,
           socket
           |> put_flash(:info, "Plan updated successfully!")
           |> assign(plans: plans, editing_plan_id: nil, edit_form: nil)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update plan. Please check your input.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Plan not found.")}
    end
  end

  def handle_event("delete_plan", %{"id" => id}, socket) do
    gym = socket.assigns.gym
    gid = gym.id

    plan =
      Fitconnex.Billing.SubscriptionPlan
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.filter(gym_id == ^gid)
      |> Ash.read!()
      |> List.first()

    if plan do
      case Ash.destroy(plan) do
        :ok ->
          plans =
            Fitconnex.Billing.SubscriptionPlan
            |> Ash.Query.filter(gym_id == ^gid)
            |> Ash.read!()

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

  defp find_gym(user_id) do
    case Fitconnex.Gym.Gym
         |> Ash.Query.filter(owner_id == ^user_id)
         |> Ash.read!() do
      [gym | _] -> {:ok, gym}
      [] -> :no_gym
    end
  end

  defp rupees_to_paise(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> round(f * 100)
      :error -> 0
    end
  end

  defp rupees_to_paise(_), do: 0

  defp format_price(paise) when is_integer(paise) do
    rupees = paise / 100
    :erlang.float_to_binary(rupees, decimals: 2)
  end

  defp format_price(_), do: "0.00"

  defp format_duration(:day_pass), do: "1 Day Pass"
  defp format_duration(:monthly), do: "1 Month"
  defp format_duration(:quarterly), do: "3 Months"
  defp format_duration(:half_yearly), do: "6 Months"
  defp format_duration(:annual), do: "12 Months"
  defp format_duration(:two_year), do: "24 Months"
  defp format_duration(other), do: Phoenix.Naming.humanize(other)

  defp plan_type_class(:general), do: "badge-primary"
  defp plan_type_class(:personal_training), do: "badge-secondary"
  defp plan_type_class(_), do: "badge-neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Plans & Billing</h1>
              <p class="text-base-content/50 mt-1">Manage subscription plans for your gym.</p>
            </div>
          </div>
          <%= if @gym do %>
            <button
              phx-click="toggle_form"
              class="btn btn-primary btn-sm gap-2 font-semibold"
              id="toggle-plan-form-btn"
            >
              <.icon name="hero-plus-mini" class="size-4" /> Create Plan
            </button>
          <% end %>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
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
          <%!-- Create Plan Form --%>
          <%= if @show_form do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="add-plan-card">
              <div class="card-body p-6">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-credit-card-solid" class="size-5 text-warning" />
                  New Subscription Plan
                </h2>
                <.form for={@form} id="add-plan-form" phx-change="validate" phx-submit="save_plan">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <.input
                      field={@form[:name]}
                      label="Plan Name"
                      placeholder="e.g. Premium Monthly"
                      required
                    />
                    <.input
                      field={@form[:plan_type]}
                      type="select"
                      label="Plan Type"
                      prompt="Select plan type"
                      options={[{"General", "general"}, {"Personal Training", "personal_training"}]}
                      required
                    />
                    <.input
                      field={@form[:duration]}
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
                      field={@form[:price_in_rupees]}
                      type="number"
                      label="Price (in Rupees)"
                      placeholder="e.g. 1000"
                      required
                    />
                  </div>
                  <div class="flex gap-2 mt-4">
                    <button type="submit" class="btn btn-primary btn-sm gap-2" id="save-plan-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Save Plan
                    </button>
                    <button
                      type="button"
                      phx-click="toggle_form"
                      class="btn btn-ghost btn-sm"
                      id="cancel-plan-btn"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Edit Plan Form --%>
          <%= if @editing_plan_id do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="edit-plan-card">
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
                    <.input
                      field={@edit_form[:name]}
                      label="Plan Name"
                      placeholder="e.g. Premium Monthly"
                      required
                    />
                    <.input
                      field={@edit_form[:plan_type]}
                      type="select"
                      label="Plan Type"
                      prompt="Select plan type"
                      options={[{"General", "general"}, {"Personal Training", "personal_training"}]}
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
                      placeholder="e.g. 1000"
                      required
                    />
                  </div>
                  <div class="flex gap-2 mt-4">
                    <button type="submit" class="btn btn-primary btn-sm gap-2" id="update-plan-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Update Plan
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

          <%!-- Plans Grid --%>
          <%= if @plans == [] do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-plans-card">
              <div class="card-body p-6 text-center">
                <.icon name="hero-credit-card-solid" class="size-12 text-base-content/20 mx-auto" />
                <h2 class="text-lg font-bold mt-4">No Plans Yet</h2>
                <p class="text-base-content/50 mt-1">
                  Create subscription plans so members can sign up.
                </p>
              </div>
            </div>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="plans-grid">
              <%= for plan <- @plans do %>
                <div class="card bg-base-200/50 border border-base-300/50" id={"plan-#{plan.id}"}>
                  <div class="card-body p-5">
                    <div class="flex items-start justify-between">
                      <div>
                        <h3 class="text-lg font-bold">{plan.name}</h3>
                        <span class={"badge badge-sm mt-1 #{plan_type_class(plan.plan_type)}"}>
                          {Phoenix.Naming.humanize(plan.plan_type)}
                        </span>
                      </div>
                      <div class="flex gap-1">
                        <button
                          phx-click="edit_plan"
                          phx-value-id={plan.id}
                          class="btn btn-ghost btn-xs text-info"
                          id={"edit-plan-#{plan.id}"}
                        >
                          <.icon name="hero-pencil-square" class="size-4" />
                        </button>
                        <button
                          phx-click="delete_plan"
                          phx-value-id={plan.id}
                          data-confirm="Are you sure you want to delete this plan?"
                          class="btn btn-ghost btn-xs text-error"
                          id={"delete-plan-#{plan.id}"}
                        >
                          <.icon name="hero-trash" class="size-4" />
                        </button>
                      </div>
                    </div>
                    <div class="divider my-2"></div>
                    <div class="space-y-2">
                      <div class="flex items-center justify-between">
                        <span class="text-sm text-base-content/60">Duration</span>
                        <span class="text-sm font-semibold">{format_duration(plan.duration)}</span>
                      </div>
                      <div class="flex items-center justify-between">
                        <span class="text-sm text-base-content/60">Price</span>
                        <span class="text-lg font-black text-primary">
                          Rs {format_price(plan.price_in_paise)}
                        </span>
                      </div>
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
end
