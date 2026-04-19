defmodule FitTrackerzWeb.Trainer.ReportDetailLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.Layouts

  @report_names %{
    "my_clients" => "My Clients",
    "client_attendance" => "Client Attendance",
    "client_subscriptions" => "Client Subscriptions",
    "workout_plans" => "Workout Plans",
    "diet_plans" => "Diet Plans",
    "my_classes" => "My Classes"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"report_type" => report_type}, _uri, socket) do
    report_name = Map.get(@report_names, report_type)

    if is_nil(report_name) do
      {:noreply,
       socket
       |> put_flash(:error, "Unknown report type.")
       |> push_navigate(to: "/trainer/reports")}
    else
      actor = socket.assigns.current_user

      {gym, gym_trainer} =
        case FitTrackerz.Gym.list_active_trainerships(actor.id, actor: actor) do
          {:ok, [gt | _]} ->
            case FitTrackerz.Gym.get_gym(gt.gym_id, actor: actor) do
              {:ok, gym} -> {gym, gt}
              _ -> {nil, gt}
            end

          _ ->
            {nil, nil}
        end

      if is_nil(gym) or is_nil(gym_trainer) do
        {:noreply,
         socket
         |> put_flash(:error, "No gym association found.")
         |> push_navigate(to: "/trainer/reports")}
      else
        today = Date.utc_today()
        start_date = Date.add(today, -30)

        socket =
          socket
          |> assign(
            page_title: report_name,
            report_type: report_type,
            report_name: report_name,
            gym: gym,
            gym_trainer: gym_trainer,
            preset: "30d",
            start_date: start_date,
            end_date: today,
            custom_start: "",
            custom_end: "",
            page: 1,
            per_page: 20,
            total_pages: 1,
            report_data: nil
          )
          |> load_report_data()

        {:noreply, socket}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("select_preset", %{"preset" => preset}, socket) do
    today = Date.utc_today()

    start_date =
      case preset do
        "7d" -> Date.add(today, -7)
        "30d" -> Date.add(today, -30)
        "90d" -> Date.add(today, -90)
        "year" -> Date.new!(today.year, 1, 1)
        _ -> Date.add(today, -30)
      end

    socket =
      socket
      |> assign(preset: preset, start_date: start_date, end_date: today, page: 1)
      |> load_report_data()

    {:noreply, socket}
  end

  def handle_event("update_custom", %{"custom_start" => start_str, "custom_end" => end_str}, socket) do
    {:noreply, assign(socket, custom_start: start_str, custom_end: end_str)}
  end

  def handle_event("apply_custom_range", %{"custom_start" => start_str, "custom_end" => end_str}, socket) do
    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str),
         true <- Date.compare(start_date, end_date) != :gt do
      socket =
        socket
        |> assign(
          preset: "custom",
          start_date: start_date,
          end_date: end_date,
          custom_start: start_str,
          custom_end: end_str,
          page: 1
        )
        |> load_report_data()

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid date range. Ensure start date is before end date.")}
    end
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    page = max(1, min(page, socket.assigns.total_pages))

    socket =
      socket
      |> assign(page: page)
      |> load_report_data()

    {:noreply, socket}
  end

  def handle_event("export_csv", _params, socket) do
    %{gym: gym, gym_trainer: gt, report_type: rt, start_date: s, end_date: e} = socket.assigns
    csv_content = fetch_csv(rt, gym.id, gt.id, s, e, [])
    filename = "#{rt}_#{Date.to_iso8601(s)}_#{Date.to_iso8601(e)}.csv"

    {:noreply, push_event(socket, "download_csv", %{filename: filename, content: csv_content})}
  end

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_report_data(socket) do
    %{gym: gym, gym_trainer: gt, report_type: rt, start_date: s, end_date: e, page: page, per_page: per_page} = socket.assigns
    report_data = fetch_report(rt, gym.id, gt.id, s, e, page: page, per_page: per_page)
    total_pages = max(ceil(report_data.total_count / per_page), 1)
    assign(socket, report_data: report_data, total_pages: total_pages)
  end

  defp fetch_report("my_clients", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.my_clients_report(gym_id, trainer_id, s, e, opts)
  defp fetch_report("client_attendance", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.client_attendance_report(gym_id, trainer_id, s, e, opts)
  defp fetch_report("client_subscriptions", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.client_subscriptions_report(gym_id, trainer_id, s, e, opts)
  defp fetch_report("workout_plans", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.workout_plans_report(gym_id, trainer_id, s, e, opts)
  defp fetch_report("diet_plans", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.diet_plans_report(gym_id, trainer_id, s, e, opts)
  defp fetch_report("my_classes", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.my_classes_report(gym_id, trainer_id, s, e, opts)

  defp fetch_csv("my_clients", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.my_clients_report_csv(gym_id, trainer_id, s, e, opts)
  defp fetch_csv("client_attendance", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.client_attendance_report_csv(gym_id, trainer_id, s, e, opts)
  defp fetch_csv("client_subscriptions", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.client_subscriptions_report_csv(gym_id, trainer_id, s, e, opts)
  defp fetch_csv("workout_plans", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.workout_plans_report_csv(gym_id, trainer_id, s, e, opts)
  defp fetch_csv("diet_plans", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.diet_plans_report_csv(gym_id, trainer_id, s, e, opts)
  defp fetch_csv("my_classes", gym_id, trainer_id, s, e, opts), do: FitTrackerz.Reports.my_classes_report_csv(gym_id, trainer_id, s, e, opts)

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp preset_label("7d"), do: "7 Days"
  defp preset_label("30d"), do: "30 Days"
  defp preset_label("90d"), do: "90 Days"
  defp preset_label("year"), do: "This Year"
  defp preset_label(_), do: "Custom"

  defp status_badge(value) when is_binary(value) do
    cond do
      value in ["Active", "active", "Paid", "paid", "Present", "present", "Completed", "completed"] ->
        "badge-success"

      value in ["Inactive", "inactive", "Expired", "expired", "Absent", "absent", "Cancelled", "cancelled"] ->
        "badge-error"

      value in ["Pending", "pending", "Upcoming", "upcoming"] ->
        "badge-warning"

      true ->
        "badge-ghost"
    end
  end

  defp status_badge(_), do: "badge-ghost"

  defp format_cell(%Date{} = date), do: Calendar.strftime(date, "%b %d, %Y")
  defp format_cell(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y %H:%M")
  defp format_cell(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y %H:%M")
  defp format_cell(nil), do: "-"
  defp format_cell(val), do: to_string(val)

  defp is_status_field?(key) do
    key in [:status, :payment_status, :attendance_status, :subscription_status]
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <div class="space-y-6" id="report-detail" phx-hook="CsvDownload">
        <.page_header title={@report_name} subtitle={@gym.name} back_path="/trainer/reports">
          <:actions>
            <%= if @report_data do %>
              <.button variant="outline" size="sm" icon="hero-arrow-down-tray" phx-click="export_csv">
                Export CSV
              </.button>
            <% end %>
          </:actions>
        </.page_header>

        <%!-- Date Range --%>
        <.card>
          <div class="flex flex-wrap items-center gap-3">
            <div class="flex gap-1">
              <%= for preset <- ["7d", "30d", "90d", "year"] do %>
                <.button
                  variant={if(@preset == preset, do: "primary", else: "ghost")}
                  size="sm"
                  phx-click="select_preset"
                  phx-value-preset={preset}
                >
                  {preset_label(preset)}
                </.button>
              <% end %>
            </div>

            <form phx-submit="apply_custom_range" phx-change="update_custom" class="flex items-center gap-2 ml-auto">
              <input
                type="date"
                name="custom_start"
                value={@custom_start}
                class="input input-sm input-bordered w-36"
              />
              <span class="text-base-content/40">to</span>
              <input
                type="date"
                name="custom_end"
                value={@custom_end}
                class="input input-sm input-bordered w-36"
              />
              <.button variant="primary" size="sm" type="submit">Apply</.button>
            </form>
          </div>
        </.card>

        <%= if @report_data do %>
          <%!-- Summary Cards --%>
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            <.stat_card
              :for={item <- @report_data.summary}
              label={item.label}
              value={item.value}
              icon="hero-chart-bar-solid"
              color="primary"
            />
          </div>

          <%!-- Data Table --%>
          <.card>
            <div class="overflow-x-auto">
              <table class="table table-sm table-zebra">
                <thead>
                  <tr class="text-base-content/40">
                    <th :for={col <- @report_data.columns}>{col.label}</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @report_data.rows == [] do %>
                    <tr>
                      <td colspan={length(@report_data.columns)} class="text-center text-base-content/50 py-8">
                        No data found for the selected period.
                      </td>
                    </tr>
                  <% else %>
                    <tr :for={row <- @report_data.rows}>
                      <td :for={col <- @report_data.columns}>
                        <%= if is_status_field?(col.key) do %>
                          <span class={"badge badge-sm #{status_badge(Map.get(row, col.key))}"}>
                            {format_cell(Map.get(row, col.key))}
                          </span>
                        <% else %>
                          {format_cell(Map.get(row, col.key))}
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <%!-- Pagination --%>
            <%= if @total_pages > 1 do %>
              <.pagination current_page={@page} total_pages={@total_pages} on_page_change="change_page" />
            <% end %>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
