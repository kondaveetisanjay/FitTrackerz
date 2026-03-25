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

  defp status_badge("Active"), do: "badge badge-sm badge-success"
  defp status_badge("Inactive"), do: "badge badge-sm badge-error"
  defp status_badge("Expired"), do: "badge badge-sm badge-error"
  defp status_badge("Cancelled"), do: "badge badge-sm badge-warning"
  defp status_badge("Paid"), do: "badge badge-sm badge-success"
  defp status_badge("Pending"), do: "badge badge-sm badge-warning"
  defp status_badge("Failed"), do: "badge badge-sm badge-error"
  defp status_badge("Refunded"), do: "badge badge-sm badge-ghost"
  defp status_badge("Confirmed"), do: "badge badge-sm badge-success"
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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <div class="flex items-center gap-3 mb-1">
              <.link navigate="/admin/reports" class="btn btn-ghost btn-sm btn-circle">
                <.icon name="hero-arrow-left-mini" class="size-4" />
              </.link>
              <h1 class="text-2xl sm:text-3xl font-brand">{@report_name}</h1>
            </div>
            <p class="text-base-content/50 ml-12">Platform-wide report</p>
          </div>
          <button phx-click="export_csv" class="btn btn-primary btn-sm gap-2">
            <.icon name="hero-arrow-down-tray-mini" class="size-4" />
            Export CSV
          </button>
        </div>

        <%!-- Date Range Controls --%>
        <div class="card bg-base-200/50 border border-base-300/50">
          <div class="card-body p-4">
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
                <button type="submit" class="btn btn-sm btn-primary">
                  Apply
                </button>
              </form>
            </div>
          </div>
        </div>

        <%!-- Summary Table --%>
        <div class="card bg-base-200/50 border border-base-300/50">
          <div class="card-body p-4">
            <h2 class="text-sm font-semibold text-base-content/60 mb-3">Summary</h2>
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Metric</th>
                  <th>Value</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={item <- @report_data.summary}>
                  <td class="font-medium">{item.label}</td>
                  <td class="font-bold">{item.value}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Detail Table --%>
        <div class="card bg-base-200/50 border border-base-300/50">
          <div class="card-body p-4">
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
                      <%= if badge_class = status_badge(value) do %>
                        <span class={badge_class}>{value}</span>
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

            <%!-- Pagination --%>
            <div class="flex items-center justify-center gap-2 mt-4">
              <button
                phx-click="change_page"
                phx-value-page={@page - 1}
                class="btn btn-sm btn-ghost"
                disabled={@page <= 1}
              >
                Previous
              </button>
              <span class="text-sm text-base-content/60">
                Page {@page} of {@total_pages}
              </span>
              <button
                phx-click="change_page"
                phx-value-page={@page + 1}
                class="btn btn-sm btn-ghost"
                disabled={@page >= @total_pages}
              >
                Next
              </button>
            </div>
          </div>
        </div>

        <%!-- CSV Download Hook --%>
        <div id="csv-download" phx-hook="CsvDownload"></div>
      </div>
    </Layouts.app>
    """
  end
end
