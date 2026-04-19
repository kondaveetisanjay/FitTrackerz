defmodule FitTrackerzWeb.GymOperator.ReportDetailLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.Layouts

  @report_names %{
    "active_members" => "Active Members",
    "new_members" => "New Members",
    "revenue" => "Revenue",
    "attendance" => "Attendance",
    "subscription_status" => "Subscription Status",
    "class_utilization" => "Class Utilization",
    "payment_collection" => "Payment Collection",
    "member_retention" => "Member Retention",
    "trainer_overview" => "Trainer Overview",
    "trainer_client_load" => "Trainer Client Load",
    "trainer_class_performance" => "Trainer Class Performance",
    "trainer_attendance" => "Trainer Attendance Impact"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"report_type" => report_type}, _uri, socket) do
    actor = socket.assigns.current_user

    report_name = Map.get(@report_names, report_type, "Unknown Report")

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        today = Date.utc_today()
        start_date = Date.add(today, -30)

        socket =
          socket
          |> assign(
            page_title: report_name,
            gym: gym,
            report_type: report_type,
            report_name: report_name,
            start_date: start_date,
            end_date: today,
            preset: "30d",
            custom_start: "",
            custom_end: "",
            page: 1,
            per_page: 10
          )
          |> load_report_data()

        {:noreply, socket}

      _ ->
        {:noreply,
         assign(socket,
           page_title: report_name,
           gym: nil,
           report_type: report_type,
           report_name: report_name,
           report_data: %{summary: [], rows: [], total_count: 0, columns: []},
           total_pages: 1,
           start_date: Date.utc_today(),
           end_date: Date.utc_today(),
           preset: "30d",
           custom_start: "",
           custom_end: "",
           page: 1,
           per_page: 10
         )}
    end
  end

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

    socket =
      socket
      |> assign(page: page)
      |> load_report_data()

    {:noreply, socket}
  end

  def handle_event("change_per_page", %{"per_page" => per_page_str}, socket) do
    per_page = String.to_integer(per_page_str)

    socket =
      socket
      |> assign(per_page: per_page, page: 1)
      |> load_report_data()

    {:noreply, socket}
  end

  def handle_event("export_csv", _params, socket) do
    %{gym: gym, report_type: report_type, start_date: s, end_date: e} = socket.assigns
    csv_string = fetch_csv(report_type, gym.id, s, e, [])
    filename = "#{report_type}_#{Date.to_iso8601(s)}_to_#{Date.to_iso8601(e)}.csv"

    {:noreply, push_event(socket, "download_csv", %{filename: filename, content: csv_string})}
  end

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_report_data(socket) do
    %{gym: gym, report_type: report_type, start_date: s, end_date: e, page: page, per_page: per_page} = socket.assigns
    report_data = fetch_report(report_type, gym.id, s, e, page: page, per_page: per_page)
    total_pages = max(ceil(report_data.total_count / per_page), 1)
    assign(socket, report_data: report_data, total_pages: total_pages)
  end

  # ---------------------------------------------------------------------------
  # Report dispatchers
  # ---------------------------------------------------------------------------

  defp fetch_report("active_members", gym_id, s, e, opts), do: FitTrackerz.Reports.active_members_report(gym_id, s, e, opts)
  defp fetch_report("new_members", gym_id, s, e, opts), do: FitTrackerz.Reports.new_members_report(gym_id, s, e, opts)
  defp fetch_report("revenue", gym_id, s, e, opts), do: FitTrackerz.Reports.revenue_report(gym_id, s, e, opts)
  defp fetch_report("attendance", gym_id, s, e, opts), do: FitTrackerz.Reports.attendance_report(gym_id, s, e, opts)
  defp fetch_report("subscription_status", gym_id, s, e, opts), do: FitTrackerz.Reports.subscription_status_report(gym_id, s, e, opts)
  defp fetch_report("class_utilization", gym_id, s, e, opts), do: FitTrackerz.Reports.class_utilization_report(gym_id, s, e, opts)
  defp fetch_report("payment_collection", gym_id, s, e, opts), do: FitTrackerz.Reports.payment_collection_report(gym_id, s, e, opts)
  defp fetch_report("member_retention", gym_id, s, e, opts), do: FitTrackerz.Reports.member_retention_report(gym_id, s, e, opts)
  defp fetch_report("trainer_overview", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_overview_report(gym_id, s, e, opts)
  defp fetch_report("trainer_client_load", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_client_load_report(gym_id, s, e, opts)
  defp fetch_report("trainer_class_performance", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_class_performance_report(gym_id, s, e, opts)
  defp fetch_report("trainer_attendance", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_attendance_report(gym_id, s, e, opts)

  defp fetch_csv("active_members", gym_id, s, e, opts), do: FitTrackerz.Reports.active_members_report_csv(gym_id, s, e, opts)
  defp fetch_csv("new_members", gym_id, s, e, opts), do: FitTrackerz.Reports.new_members_report_csv(gym_id, s, e, opts)
  defp fetch_csv("revenue", gym_id, s, e, opts), do: FitTrackerz.Reports.revenue_report_csv(gym_id, s, e, opts)
  defp fetch_csv("attendance", gym_id, s, e, opts), do: FitTrackerz.Reports.attendance_report_csv(gym_id, s, e, opts)
  defp fetch_csv("subscription_status", gym_id, s, e, opts), do: FitTrackerz.Reports.subscription_status_report_csv(gym_id, s, e, opts)
  defp fetch_csv("class_utilization", gym_id, s, e, opts), do: FitTrackerz.Reports.class_utilization_report_csv(gym_id, s, e, opts)
  defp fetch_csv("payment_collection", gym_id, s, e, opts), do: FitTrackerz.Reports.payment_collection_report_csv(gym_id, s, e, opts)
  defp fetch_csv("member_retention", gym_id, s, e, opts), do: FitTrackerz.Reports.member_retention_report_csv(gym_id, s, e, opts)
  defp fetch_csv("trainer_overview", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_overview_report_csv(gym_id, s, e, opts)
  defp fetch_csv("trainer_client_load", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_client_load_report_csv(gym_id, s, e, opts)
  defp fetch_csv("trainer_class_performance", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_class_performance_report_csv(gym_id, s, e, opts)
  defp fetch_csv("trainer_attendance", gym_id, s, e, opts), do: FitTrackerz.Reports.trainer_attendance_report_csv(gym_id, s, e, opts)

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp preset_label("7d"), do: "7 Days"
  defp preset_label("30d"), do: "30 Days"
  defp preset_label("90d"), do: "90 Days"
  defp preset_label("year"), do: "This Year"
  defp preset_label(_), do: "Custom"

  defp showing_from(page, per_page), do: (page - 1) * per_page + 1
  defp showing_to(page, per_page, total), do: min(page * per_page, total)

  defp status_badge("Active"), do: "success"
  defp status_badge("Inactive"), do: "error"
  defp status_badge("Expired"), do: "error"
  defp status_badge("Cancelled"), do: "warning"
  defp status_badge("Paid"), do: "success"
  defp status_badge("Pending"), do: "warning"
  defp status_badge("Failed"), do: "error"
  defp status_badge("Refunded"), do: "neutral"
  defp status_badge("Confirmed"), do: "success"
  defp status_badge(_), do: nil

  defp format_cell_value(value) when is_binary(value), do: value
  defp format_cell_value(nil), do: "-"
  defp format_cell_value(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_cell_value(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_cell_value(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_cell_value(value) when is_number(value), do: to_string(value)
  defp format_cell_value(value), do: to_string(value)

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <div class="space-y-6">
        <%= if @gym do %>
          <.page_header title={@report_name} subtitle={@gym.name} back_path="/gym/reports">
            <:actions>
              <.button variant="primary" size="sm" icon="hero-arrow-down-tray-mini" phx-click="export_csv">Export CSV</.button>
            </:actions>
          </.page_header>

          <%!-- Date Range Controls --%>
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

          <%!-- Summary --%>
          <.card title="Summary">
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
              <div :for={item <- @report_data.summary} class="text-center p-3 rounded-lg bg-base-200/50">
                <p class="text-sm text-base-content/60">{item.label}</p>
                <p class="text-2xl font-bold mt-1">{item.value}</p>
              </div>
            </div>
          </.card>

          <%!-- Detail Table --%>
          <.card>
            <div class="flex flex-wrap items-center justify-between mb-3">
              <p class="text-sm text-base-content/60">
                Showing {showing_from(@page, @per_page)} to {showing_to(@page, @per_page, @report_data.total_count)} of {@report_data.total_count} records
              </p>
              <form phx-change="change_per_page" class="inline">
                <select name="per_page" class="select select-xs select-bordered">
                  <option :for={size <- [10, 25, 50, 100]} value={size} selected={size == @per_page}>
                    {size} per page
                  </option>
                </select>
              </form>
            </div>

            <div class="overflow-x-auto">
              <table class="table table-sm table-zebra">
                <thead>
                  <tr>
                    <th>S.No</th>
                    <th :for={col <- @report_data.columns}>{col.label}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{row, idx} <- Enum.with_index(@report_data.rows)}>
                    <td>{showing_from(@page, @per_page) + idx}</td>
                    <td :for={col <- @report_data.columns}>
                      <% value = format_cell_value(Map.get(row, col.key)) %>
                      <%= if badge_variant = status_badge(value) do %>
                        <.badge variant={badge_variant}>{value}</.badge>
                      <% else %>
                        {value}
                      <% end %>
                    </td>
                  </tr>
                  <%= if Enum.empty?(@report_data.rows) do %>
                    <tr>
                      <td colspan={length(@report_data.columns) + 1} class="text-center text-base-content/50 py-8">
                        No records found for the selected period.
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <.pagination current_page={@page} total_pages={@total_pages} on_page_change="change_page" />
          </.card>

          <%!-- CSV Download Hook --%>
          <div id="csv-download" phx-hook="CsvDownload"></div>
        <% else %>
          <.empty_state icon="hero-building-office-2" title="No Gym Found" subtitle="Please set up your gym first.">
            <:action>
              <.button variant="primary" size="sm" navigate="/gym/setup">Set Up Gym</.button>
            </:action>
          </.empty_state>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
