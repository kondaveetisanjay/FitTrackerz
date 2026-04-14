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
        {:ok, assign(socket, page_title: "Health Log", no_gym: true, metrics: [], form: nil, last_height: nil, measurements: [], measurement_form: nil)}

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

        measurements =
          case FitTrackerz.Health.list_body_measurements(member_ids, actor: actor) do
            {:ok, m} -> m
            _ -> []
          end

        measurement_form =
          to_form(
            %{
              "recorded_on" => Date.to_iso8601(Date.utc_today()),
              "chest_cm" => "",
              "waist_cm" => "",
              "hips_cm" => "",
              "bicep_cm" => "",
              "thigh_cm" => "",
              "muscle_mass_kg" => "",
              "notes" => ""
            },
            as: "measurement"
          )

        {:ok,
         assign(socket,
           page_title: "Health Log",
           no_gym: false,
           membership: membership,
           metrics: metrics,
           form: form,
           last_height: last_height,
           measurements: measurements,
           measurement_form: measurement_form
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

  def handle_event("validate_measurement", %{"measurement" => params}, socket) do
    form = to_form(params, as: "measurement")
    {:noreply, assign(socket, measurement_form: form)}
  end

  def handle_event("save_measurement", %{"measurement" => params}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    attrs = %{
      member_id: membership.id,
      recorded_on: params["recorded_on"],
      chest_cm: parse_decimal(params["chest_cm"]),
      waist_cm: parse_decimal(params["waist_cm"]),
      hips_cm: parse_decimal(params["hips_cm"]),
      bicep_cm: parse_decimal(params["bicep_cm"]),
      thigh_cm: parse_decimal(params["thigh_cm"]),
      muscle_mass_kg: parse_decimal(params["muscle_mass_kg"]),
      notes: params["notes"]
    }

    case FitTrackerz.Health.log_body_measurement(attrs, actor: actor) do
      {:ok, _} ->
        measurements =
          case FitTrackerz.Health.list_body_measurements([membership.id], actor: actor) do
            {:ok, m} -> m
            _ -> []
          end

        measurement_form =
          to_form(
            %{
              "recorded_on" => Date.to_iso8601(Date.utc_today()),
              "chest_cm" => "",
              "waist_cm" => "",
              "hips_cm" => "",
              "bicep_cm" => "",
              "thigh_cm" => "",
              "muscle_mass_kg" => "",
              "notes" => ""
            },
            as: "measurement"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Measurement saved!")
         |> assign(measurements: measurements, measurement_form: measurement_form)}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("delete_measurement", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership
    measurement = Enum.find(socket.assigns.measurements, &(&1.id == id))

    if measurement do
      case FitTrackerz.Health.destroy_body_measurement(measurement, actor: actor) do
        :ok ->
          measurements =
            case FitTrackerz.Health.list_body_measurements([membership.id], actor: actor) do
              {:ok, m} -> m
              _ -> []
            end

          {:noreply,
           socket
           |> put_flash(:info, "Measurement deleted.")
           |> assign(measurements: measurements)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete measurement.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Measurement not found.")}
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
      <.page_header title="Health Log" subtitle="Track your weight, BMI, and body composition." back_path="/member" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You need a gym membership to track your health metrics."
        />
      <% else %>
        <div class="space-y-8">
          <%!-- Log Form --%>
          <.card title="Log Entry" id="health-form-card">
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
                  <.button variant="primary" size="sm" icon="hero-check" type="submit" id="save-health-btn">
                    Save
                  </.button>
                </div>
              </div>
            </.form>
          </.card>

          <%!-- History --%>
          <.card title="History" id="health-history-card">
            <:header_actions>
              <.badge variant="neutral">{length(@metrics)} entries</.badge>
            </:header_actions>
            <%= if @metrics == [] do %>
              <.empty_state
                icon="hero-chart-bar"
                title="No Entries Yet"
                subtitle="Log your first measurement above!"
              />
            <% else %>
              <.data_table id="health-table" rows={Enum.with_index(@metrics)} row_id={fn {m, _idx} -> "metric-#{m.id}" end} row_item={fn {m, _idx} -> {m, elem({m, Enum.find_index(Enum.with_index(@metrics), fn {x, _} -> x.id == m.id end) || 0}, 1)} end}>
                <:col :let={{metric, _idx}} label="Date">
                  <span class="font-medium">{Calendar.strftime(metric.recorded_on, "%b %d, %Y")}</span>
                </:col>
                <:col :let={{metric, _idx}} label="Weight">
                  {format_decimal(metric.weight_kg)} kg
                </:col>
                <:col :let={{metric, _idx}} label="BMI">
                  {format_decimal(metric.bmi)}
                  <span class="text-xs text-base-content/40 ml-1">{bmi_category(metric.bmi)}</span>
                </:col>
                <:col :let={{metric, _idx}} label="Body Fat">
                  <%= if metric.body_fat_pct do %>
                    {format_decimal(metric.body_fat_pct)}%
                  <% else %>
                    <span class="text-base-content/30">--</span>
                  <% end %>
                </:col>
              </.data_table>
              <%!-- Simpler table for change column and delete action --%>
              <div class="overflow-x-auto mt-4">
                <table class="table table-sm" id="health-detail-table">
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
                              <span class="text-success font-medium">
                                <.icon name="hero-arrow-trending-down-mini" class="size-3 inline" /> {abs_str} kg
                              </span>
                            <% else %>
                              <span class="text-warning font-medium">
                                <.icon name="hero-arrow-trending-up-mini" class="size-3 inline" /> {abs_str} kg
                              </span>
                            <% end %>
                          <% else %>
                            <span class="text-base-content/30">--</span>
                          <% end %>
                        </td>
                        <td>
                          <.button
                            variant="ghost"
                            size="sm"
                            icon="hero-trash"
                            phx-click="delete"
                            phx-value-id={metric.id}
                            data-confirm="Delete this entry?"
                            class="text-error"
                            id={"delete-metric-#{metric.id}"}
                          >
                          </.button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </.card>

          <%!-- Body Measurements --%>
          <.card title="Body Measurements" id="measurements-card">
            <:header_actions>
              <.badge variant="neutral">{length(@measurements)} entries</.badge>
            </:header_actions>

            <.form for={@measurement_form} id="measurement-form" phx-change="validate_measurement" phx-submit="save_measurement">
              <div class="flex flex-wrap gap-4 items-end">
                <div>
                  <.input field={@measurement_form[:recorded_on]} type="date" label="Date" required />
                </div>
                <div>
                  <.input field={@measurement_form[:chest_cm]} type="number" label="Chest (cm)" step="0.1" />
                </div>
                <div>
                  <.input field={@measurement_form[:waist_cm]} type="number" label="Waist (cm)" step="0.1" />
                </div>
                <div>
                  <.input field={@measurement_form[:hips_cm]} type="number" label="Hips (cm)" step="0.1" />
                </div>
                <div>
                  <.input field={@measurement_form[:bicep_cm]} type="number" label="Bicep (cm)" step="0.1" />
                </div>
                <div>
                  <.input field={@measurement_form[:thigh_cm]} type="number" label="Thigh (cm)" step="0.1" />
                </div>
                <div>
                  <.input field={@measurement_form[:muscle_mass_kg]} type="number" label="Muscle (kg)" step="0.1" />
                </div>
                <div>
                  <.input field={@measurement_form[:notes]} type="text" label="Notes" placeholder="Optional" />
                </div>
                <div class="mb-2">
                  <.button variant="primary" size="sm" icon="hero-check" type="submit" id="save-measurement-btn">
                    Save
                  </.button>
                </div>
              </div>
            </.form>

            <%= if @measurements != [] do %>
              <div class="overflow-x-auto mt-4">
                <table class="table table-sm" id="measurements-table">
                  <thead>
                    <tr class="text-base-content/40">
                      <th>Date</th>
                      <th>Chest</th>
                      <th>Waist</th>
                      <th>Hips</th>
                      <th>Bicep</th>
                      <th>Thigh</th>
                      <th>Muscle</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for m <- @measurements do %>
                      <tr id={"measurement-#{m.id}"} class="border-b border-base-300/30">
                        <td class="font-medium">{Calendar.strftime(m.recorded_on, "%b %d, %Y")}</td>
                        <td>{format_decimal(m.chest_cm)}</td>
                        <td>{format_decimal(m.waist_cm)}</td>
                        <td>{format_decimal(m.hips_cm)}</td>
                        <td>{format_decimal(m.bicep_cm)}</td>
                        <td>{format_decimal(m.thigh_cm)}</td>
                        <td>{format_decimal(m.muscle_mass_kg)}</td>
                        <td>
                          <.button
                            variant="ghost"
                            size="sm"
                            icon="hero-trash"
                            phx-click="delete_measurement"
                            phx-value-id={m.id}
                            data-confirm="Delete this measurement?"
                            class="text-error"
                            id={"delete-m-#{m.id}"}
                          >
                          </.button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </.card>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
