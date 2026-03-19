defmodule FitTrackerzWeb.Member.HealthLive do
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
        {:ok, assign(socket, page_title: "Health Log", no_gym: true, metrics: [], form: nil, last_height: nil)}

      memberships ->
        member_ids = Enum.map(memberships, & &1.id)
        membership = List.first(memberships)

        metrics = case FitTrackerz.Health.list_health_metrics(member_ids, actor: actor) do
          {:ok, metrics} -> metrics
          _ -> []
        end

        last_height = case metrics do
          [latest | _] -> latest.height_cm
          [] -> nil
        end

        form = to_form(%{
          "recorded_on" => Date.to_iso8601(Date.utc_today()),
          "weight_kg" => "",
          "height_cm" => if(last_height, do: Decimal.to_string(last_height), else: ""),
          "body_fat_pct" => "",
          "notes" => ""
        }, as: "metric")

        {:ok,
         assign(socket,
           page_title: "Health Log",
           no_gym: false,
           membership: membership,
           metrics: metrics,
           form: form,
           last_height: last_height
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"metric" => params}, socket) do
    form = to_form(params, as: "metric")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"metric" => params}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    height = parse_decimal(params["height_cm"])
    height = height || socket.assigns.last_height

    attrs = %{
      member_id: membership.id,
      gym_id: membership.gym_id,
      recorded_on: params["recorded_on"],
      weight_kg: parse_decimal(params["weight_kg"]),
      height_cm: height,
      body_fat_pct: parse_decimal(params["body_fat_pct"]),
      notes: params["notes"]
    }

    case FitTrackerz.Health.create_health_metric(attrs, actor: actor) do
      {:ok, _metric} ->
        member_ids = [membership.id]
        metrics = case FitTrackerz.Health.list_health_metrics(member_ids, actor: actor) do
          {:ok, m} -> m
          _ -> []
        end

        last_height = case metrics do
          [latest | _] -> latest.height_cm
          [] -> nil
        end

        form = to_form(%{
          "recorded_on" => Date.to_iso8601(Date.utc_today()),
          "weight_kg" => "",
          "height_cm" => if(last_height, do: Decimal.to_string(last_height), else: ""),
          "body_fat_pct" => "",
          "notes" => ""
        }, as: "metric")

        {:noreply,
         socket
         |> put_flash(:info, "Health entry saved!")
         |> assign(metrics: metrics, form: form, last_height: last_height)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    metric = Enum.find(socket.assigns.metrics, &(&1.id == id))

    if metric do
      case FitTrackerz.Health.destroy_health_metric(metric, actor: actor) do
        :ok ->
          metrics = case FitTrackerz.Health.list_health_metrics([membership.id], actor: actor) do
            {:ok, m} -> m
            _ -> []
          end

          {:noreply,
           socket
           |> put_flash(:info, "Entry deleted.")
           |> assign(metrics: metrics)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete entry.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Entry not found.")}
    end
  end

  defp parse_decimal(""), do: nil
  defp parse_decimal(nil), do: nil
  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, _} -> d
      :error -> nil
    end
  end
  defp parse_decimal(%Decimal{} = d), do: d

  defp format_decimal(nil), do: "--"
  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_decimal(val), do: to_string(val)

  defp weight_change(metrics, index) do
    current = Enum.at(metrics, index)
    previous = Enum.at(metrics, index + 1)

    if current && previous do
      diff = Decimal.sub(current.weight_kg, previous.weight_kg)
      {Decimal.to_float(diff), Decimal.to_string(Decimal.abs(diff), :normal)}
    else
      nil
    end
  end

  defp bmi_category(nil), do: ""
  defp bmi_category(bmi) do
    val = Decimal.to_float(bmi)
    cond do
      val < 18.5 -> "Underweight"
      val < 25.0 -> "Normal"
      val < 30.0 -> "Overweight"
      true -> "Obese"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">Health Log</h1>
            <p class="text-base-content/50 mt-1">Track your weight, BMI, and body composition.</p>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <div class="w-16 h-16 rounded-2xl bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-building-office-2" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Membership</h2>
              <p class="text-sm text-base-content/50 max-w-md mt-2">
                You need a gym membership to track your health metrics.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Log Form --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="health-form-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-plus-circle-solid" class="size-5 text-success" /> Log Entry
              </h2>
              <.form for={@form} id="health-form" phx-change="validate" phx-submit="save">
                <div class="flex flex-wrap gap-4 items-end">
                  <div>
                    <.input field={@form[:recorded_on]} type="date" label="Date" required />
                  </div>
                  <div>
                    <.input field={@form[:weight_kg]} type="number" label="Weight (kg)" step="0.1" required />
                  </div>
                  <div>
                    <.input field={@form[:height_cm]} type="number" label="Height (cm)" step="0.1" />
                  </div>
                  <div>
                    <.input field={@form[:body_fat_pct]} type="number" label="Body Fat %" step="0.1" />
                  </div>
                  <div>
                    <.input field={@form[:notes]} type="text" label="Notes" placeholder="Optional" />
                  </div>
                  <div class="mb-2">
                    <button type="submit" class="btn btn-success btn-sm gap-2" id="save-health-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Save
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>

          <%!-- History --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="health-history-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-chart-bar-solid" class="size-5 text-primary" /> History
                <span class="badge badge-neutral badge-sm">{length(@metrics)}</span>
              </h2>
              <%= if @metrics == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <p class="text-sm text-base-content/50">No entries yet. Log your first measurement above!</p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="health-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Date</th>
                        <th>Weight</th>
                        <th>BMI</th>
                        <th>Body Fat</th>
                        <th>Change</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for {metric, idx} <- Enum.with_index(@metrics) do %>
                        <tr id={"metric-#{metric.id}"}>
                          <td class="font-medium">{Calendar.strftime(metric.recorded_on, "%b %d, %Y")}</td>
                          <td>{format_decimal(metric.weight_kg)} kg</td>
                          <td>
                            {format_decimal(metric.bmi)}
                            <span class="text-xs text-base-content/40 ml-1">{bmi_category(metric.bmi)}</span>
                          </td>
                          <td>
                            <%= if metric.body_fat_pct do %>
                              {format_decimal(metric.body_fat_pct)}%
                            <% else %>
                              <span class="text-base-content/30">--</span>
                            <% end %>
                          </td>
                          <td>
                            <% change = weight_change(@metrics, idx) %>
                            <%= if change do %>
                              <% {diff, abs_str} = change %>
                              <%= if diff < 0 do %>
                                <span class="text-success font-medium">↓ {abs_str} kg</span>
                              <% else %>
                                <span class="text-warning font-medium">↑ {abs_str} kg</span>
                              <% end %>
                            <% else %>
                              <span class="text-base-content/30">—</span>
                            <% end %>
                          </td>
                          <td>
                            <button
                              phx-click="delete"
                              phx-value-id={metric.id}
                              data-confirm="Delete this entry?"
                              class="btn btn-ghost btn-xs text-error"
                              id={"delete-metric-#{metric.id}"}
                            >
                              <.icon name="hero-trash-mini" class="size-3.5" />
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
