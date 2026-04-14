defmodule FitTrackerzWeb.Admin.ReportDetailLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.Layouts

  @report_names %{
    "gyms" => "Gyms",
    "members" => "Members",
    "revenue" => "Revenue",
    "subscriptions" => "Subscriptions",
    "trainers" => "Trainers",
    "attendance" => "Attendance"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"report_type" => report_type}, _uri, socket) do
    report_name = Map.get(@report_names, report_type, "Unknown Report")

    today = Date.utc_today()
    start_date = Date.add(today, -30)

    socket =
      socket
      |> assign(
        page_title: report_name,
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
    %{report_type: report_type, start_date: s, end_date: e} = socket.assigns
    csv_string = fetch_csv(report_type, s, e, [])
    filename = "#{report_type}_#{Date.to_iso8601(s)}_to_#{Date.to_iso8601(e)}.csv"

    {:noreply, push_event(socket, "download_csv", %{filename: filename, content: csv_string})}
  end

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_report_data(socket) do
    %{report_type: rt, start_date: s, end_date: e, page: page, per_page: per_page} = socket.assigns
    report_data = fetch_report(rt, s, e, page: page, per_page: per_page)
    total_pages = max(ceil(report_data.total_count / per_page), 1)
    assign(socket, report_data: report_data, total_pages: total_pages)
  end

  # ---------------------------------------------------------------------------
  # Report dispatchers
  # ---------------------------------------------------------------------------

  defp fetch_report("gyms", s, e, opts), do: FitTrackerz.Reports.admin_gyms_report(s, e, opts)
  defp fetch_report("members", s, e, opts), do: FitTrackerz.Reports.admin_members_report(s, e, opts)
  defp fetch_report("revenue", s, e, opts), do: FitTrackerz.Reports.admin_revenue_report(s, e, opts)
  defp fetch_report("subscriptions", s, e, opts), do: FitTrackerz.Reports.admin_subscriptions_report(s, e, opts)
  defp fetch_report("trainers", s, e, opts), do: FitTrackerz.Reports.admin_trainers_report(s, e, opts)
  defp fetch_report("attendance", s, e, opts), do: FitTrackerz.Reports.admin_attendance_report(s, e, opts)

  defp fetch_csv("gyms", s, e, opts), do: FitTrackerz.Reports.admin_gyms_report_csv(s, e, opts)
  defp fetch_csv("members", s, e, opts), do: FitTrackerz.Reports.admin_members_report_csv(s, e, opts)
  defp fetch_csv("revenue", s, e, opts), do: FitTrackerz.Reports.admin_revenue_report_csv(s, e, opts)
  defp fetch_csv("subscriptions", s, e, opts), do: FitTrackerz.Reports.admin_subscriptions_report_csv(s, e, opts)
  defp fetch_csv("trainers", s, e, opts), do: FitTrackerz.Reports.admin_trainers_report_csv(s, e, opts)
  defp fetch_csv("attendance", s, e, opts), do: FitTrackerz.Reports.admin_attendance_report_csv(s, e, opts)

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

  defp status_badge_variant("Active"), do: "success"
  defp status_badge_variant("Inactive"), do: "error"
  defp status_badge_variant("Expired"), do: "error"
  defp status_badge_variant("Cancelled"), do: "warning"
  defp status_badge_variant("Paid"), do: "success"
  defp status_badge_variant("Pending"), do: "warning"
  defp status_badge_variant("Failed"), do: "error"
  defp status_badge_variant("Refunded"), do: "neutral"
  defp status_badge_variant("Confirmed"), do: "success"
  defp status_badge_variant(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title={@report_name} subtitle="Platform-wide report" back_path="/admin/reports">
        <:actions>
          <.button variant="primary" size="sm" icon="hero-arrow-down-tray" phx-click="export_csv">
            Export CSV
          </.button>
        </:actions>
      </.page_header>

      <%!-- Date Range Controls --%>
      <.section>
        <.card padded={false}>
          <div class="p-4">
            <div class="flex flex-wrap items-center gap-3">
              <div class="flex gap-1">
                <%= for preset <- ["7d", "30d", "90d", "year"] do %>
                  <button
                    phx-click="select_preset"
                    phx-value-preset={preset}
                    class={[
                      "btn btn-sm",
                      if(@preset == preset, do: "btn-primary", else: "btn-ghost")
                    ]}
                  >
                    {preset_label(preset)}
                  </button>
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
                <.button type="submit" variant="primary" size="sm">Apply</.button>
              </form>
            </div>
          </div>
        </.card>
      </.section>

      <%!-- Summary --%>
      <.section title="Summary">
        <.card padded={false}>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr class="border-b border-base-300/50">
                  <th class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">Metric</th>
                  <th class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">Value</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={item <- @report_data.summary} class="border-b border-base-300/30">
                  <td class="font-medium">{item.label}</td>
                  <td class="font-bold">{item.value}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </.card>
      </.section>

      <%!-- Detail Table --%>
      <.section title="Details">
        <:actions>
          <div class="flex items-center gap-3">
            <p class="text-sm text-base-content/60">
              Showing {showing_from(@page, @per_page)}-{showing_to(@page, @per_page, @report_data.total_count)} of {@report_data.total_count}
            </p>
            <form phx-change="change_per_page" class="inline">
              <select name="per_page" class="select select-xs select-bordered">
                <option :for={size <- [10, 25, 50, 100]} value={size} selected={size == @per_page}>
                  {size} per page
                </option>
              </select>
            </form>
          </div>
        </:actions>

        <.card padded={false}>
          <%= if Enum.empty?(@report_data.rows) do %>
            <.empty_state
              icon="hero-document-magnifying-glass"
              title="No records found"
              subtitle="No records found for the selected period."
            />
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr class="border-b border-base-300/50">
                    <th class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">S.No</th>
                    <th
                      :for={col <- @report_data.columns}
                      class="text-xs font-semibold text-base-content/50 uppercase tracking-wider"
                    >
                      {col.label}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{row, idx} <- Enum.with_index(@report_data.rows)} class="border-b border-base-300/30 hover:bg-base-200/50">
                    <td class="text-base-content/50">{showing_from(@page, @per_page) + idx}</td>
                    <td :for={col <- @report_data.columns}>
                      <% value = format_cell_value(Map.get(row, col.key)) %>
                      <%= if variant = status_badge_variant(value) do %>
                        <.badge variant={variant} size="sm">{value}</.badge>
                      <% else %>
                        {value}
                      <% end %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>

          <%!-- Pagination --%>
          <div class="px-4 pb-4">
            <.pagination current_page={@page} total_pages={@total_pages} on_page_change="change_page" />
          </div>
        </.card>
      </.section>

      <%!-- CSV Download Hook --%>
      <div id="csv-download" phx-hook="CsvDownload"></div>
    </Layouts.app>
    """
  end
end
