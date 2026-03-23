# Reports & Dashboard Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename Analytics to Dashboards with visualization type dropdown, add Operator Reports page (12 predefined reports with paginated tables + CSV export), and Trainer Reports page (6 self-reports).

**Architecture:** Extend existing dashboard page with viz type switching. New `FitTrackerz.Reports` context module with Ecto queries returning summary + paginated detail data. Two pairs of LiveViews (list + detail) for operator and trainer reports. CSV export via JS hook. All queries against existing tables.

**Tech Stack:** Ecto queries, Phoenix LiveView, Chart.js (existing), DaisyUI/Tailwind CSS

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/fit_trackerz/reports.ex` | Report query functions — 12 operator + 6 trainer reports |
| `lib/fit_trackerz_web/live/gym_operator/reports_live.ex` | Operator report list page |
| `lib/fit_trackerz_web/live/gym_operator/report_detail_live.ex` | Operator single report view |
| `lib/fit_trackerz_web/live/trainer/reports_live.ex` | Trainer report list page |
| `lib/fit_trackerz_web/live/trainer/report_detail_live.ex` | Trainer single report view |

### Modified Files

| File | Change |
|------|--------|
| `lib/fit_trackerz_web/live/gym_operator/analytics_live.ex` | Rename to `dashboards_live.ex`, change module name, add viz dropdown |
| `lib/fit_trackerz_web/router.ex` | Rename route, add report routes for both roles |
| `lib/fit_trackerz_web/components/layouts.ex` | Rename nav label, add Reports links |
| `assets/js/app.js` | Add CsvDownload hook |

---

### Task 1: Rename Analytics → Dashboards

**Files:**
- Rename: `lib/fit_trackerz_web/live/gym_operator/analytics_live.ex` → `dashboards_live.ex`
- Modify: `lib/fit_trackerz_web/router.ex`
- Modify: `lib/fit_trackerz_web/components/layouts.ex`

- [ ] **Step 1: Rename the file**

```bash
mv lib/fit_trackerz_web/live/gym_operator/analytics_live.ex lib/fit_trackerz_web/live/gym_operator/dashboards_live.ex
```

- [ ] **Step 2: Update the module name and page title**

In `dashboards_live.ex`:
- Change `defmodule FitTrackerzWeb.GymOperator.AnalyticsLive do` → `defmodule FitTrackerzWeb.GymOperator.DashboardsLive do`
- Change both `page_title: "Analytics"` → `page_title: "Dashboards"`
- Change `<h1 ...>Analytics</h1>` → `<h1 ...>Dashboards</h1>`
- Change `<p ...>Performance metrics for` text to `Dashboard metrics for`

- [ ] **Step 3: Update router**

In `router.ex`, gym operator scope:
- Change `live "/analytics", AnalyticsLive` → `live "/dashboards", DashboardsLive`

- [ ] **Step 4: Update sidebar nav**

In `layouts.ex`, gym operator sidebar:
- Change `href="/gym/analytics"` → `href="/gym/dashboards"`
- Change `label="Analytics"` → `label="Dashboards"`

- [ ] **Step 5: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 2: Add Visualization Type Dropdown to Dashboards

**Files:**
- Modify: `lib/fit_trackerz_web/live/gym_operator/dashboards_live.ex`

- [ ] **Step 1: Add viz_types to assigns in mount**

After existing assigns, add a map tracking the selected visualization type per chart:

```elixir
viz_types: %{
  "new-members-chart" => "line",
  "revenue-chart" => "bar",
  "attendance-chart" => "line",
  "retention-chart" => "line",
  "subscription-chart" => "doughnut",
  "payment-chart" => "doughnut",
  "class-chart" => "bar"
}
```

- [ ] **Step 2: Add handle_event for viz type change**

```elixir
def handle_event("change_viz", %{"chart_id" => chart_id, "viz_type" => viz_type}, socket) do
  viz_types = Map.put(socket.assigns.viz_types, chart_id, viz_type)
  {:noreply, socket |> assign(viz_types: viz_types) |> load_all_metrics()}
end
```

- [ ] **Step 3: Modify chart builders to accept viz_type parameter**

Each `build_*_chart` function needs to accept a `viz_type` parameter and return the appropriate chart config. When viz_type is "table", return a special `%{type: "table", data: %{headers: [...], rows: [...]}}` map instead of a Chart.js config.

Update `load_all_metrics/1` to pass `viz_types` to each builder:

```elixir
new_members_chart: build_new_members_chart(new_members.daily, viz_types["new-members-chart"]),
revenue_chart: build_revenue_chart(revenue.daily, viz_types["revenue-chart"]),
# ... etc
```

Each builder:
```elixir
defp build_new_members_chart(daily, "table") do
  %{type: "table", data: %{
    headers: ["Date", "New Members"],
    rows: Enum.map(daily, fn d -> [format_date(d.date), d.value] end)
  }}
end
defp build_new_members_chart(daily, viz_type) do
  # Existing chart config but with type set to viz_type ("line" or "bar")
  %{
    type: viz_type,
    data: %{labels: ..., datasets: [%{...}]},
    options: %{scales: %{x: %{}, y: %{}}}
  }
end
```

For categorical charts (subscription, payment):
```elixir
defp build_subscription_chart(subscriptions, "table") do
  %{type: "table", data: %{
    headers: ["Status", "Count"],
    rows: [["Active", Map.get(subscriptions, "active", 0)], ...]
  }}
end
defp build_subscription_chart(subscriptions, viz_type) do
  # viz_type is "doughnut" or "bar"
  # For "bar", return bar chart config. For "doughnut", return doughnut config.
  ...
end
```

- [ ] **Step 4: Update chart_card component with dropdown + table rendering**

```elixir
attr :id, :string, required: true
attr :title, :string, required: true
attr :chart_data, :map, required: true
attr :viz_options, :list, required: true
attr :current_viz, :string, required: true

defp chart_card(assigns) do
  ~H"""
  <div class="card bg-base-200/50 border border-base-300/50">
    <div class="card-body p-4">
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-sm font-semibold text-base-content/60">{@title}</h3>
        <select
          phx-change="change_viz"
          name="viz_type"
          class="select select-xs select-bordered"
          data-chart-id={@id}
          phx-value-chart_id={@id}
        >
          <option :for={opt <- @viz_options} value={opt} selected={opt == @current_viz}>
            {viz_label(opt)}
          </option>
        </select>
      </div>
      <%= if @chart_data[:type] == "table" do %>
        <div class="overflow-x-auto" style="height: 250px;">
          <table class="table table-sm table-zebra">
            <thead>
              <tr>
                <th :for={h <- @chart_data.data.headers} class="text-xs">{h}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @chart_data.data.rows}>
                <td :for={cell <- row} class="text-sm">{cell}</td>
              </tr>
            </tbody>
          </table>
        </div>
      <% else %>
        <div id={@id} phx-hook="ChartHook" data-chart={Jason.encode!(@chart_data)}>
          <canvas class="w-full" style="height: 250px;"></canvas>
        </div>
      <% end %>
    </div>
  </div>
  """
end

defp viz_label("line"), do: "Line Chart"
defp viz_label("bar"), do: "Bar Chart"
defp viz_label("doughnut"), do: "Pie Chart"
defp viz_label("table"), do: "Table"
defp viz_label(other), do: other
```

- [ ] **Step 5: Update render to pass viz_options and current_viz to each chart_card**

```elixir
<.chart_card
  id="new-members-chart"
  title="New Members"
  chart_data={@new_members_chart}
  viz_options={["line", "bar", "table"]}
  current_viz={@viz_types["new-members-chart"]}
/>
```

Time-series charts get `["line", "bar", "table"]`.
Categorical charts get `["doughnut", "bar", "table"]`.

- [ ] **Step 6: Fix the select phx-change to pass chart_id**

The `select` element's `phx-change` sends form data. We need to extract the chart_id. Use a hidden input or a wrapping form:

```elixir
<form phx-change="change_viz" class="inline">
  <input type="hidden" name="chart_id" value={@id} />
  <select name="viz_type" class="select select-xs select-bordered">
    <option :for={opt <- @viz_options} value={opt} selected={opt == @current_viz}>
      {viz_label(opt)}
    </option>
  </select>
</form>
```

- [ ] **Step 7: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 3: Routes + Sidebar for Reports (Operator + Trainer)

**Files:**
- Modify: `lib/fit_trackerz_web/router.ex`
- Modify: `lib/fit_trackerz_web/components/layouts.ex`

- [ ] **Step 1: Add routes**

In gym operator scope:
```elixir
live "/reports", ReportsLive
live "/reports/:report_type", ReportDetailLive
```

In trainer scope:
```elixir
live "/reports", ReportsLive
live "/reports/:report_type", ReportDetailLive
```

- [ ] **Step 2: Add sidebar nav links**

In `layouts.ex` gym operator sidebar, after Dashboards link:
```html
<.nav_link href="/gym/reports" icon="hero-document-chart-bar-solid" label="Reports" />
```

In trainer sidebar, in the Communication section (after Messages):
```html
<.nav_link href="/trainer/reports" icon="hero-document-chart-bar-solid" label="Reports" />
```

- [ ] **Step 3: Verify compilation**

```bash
mix compile
```

(Warnings about missing modules expected.)

---

### Task 4: CsvDownload JS Hook

**Files:**
- Modify: `assets/js/app.js`

- [ ] **Step 1: Add the CsvDownload hook**

```javascript
const CsvDownload = {
  mounted() {
    this.handleEvent("download_csv", ({filename, content}) => {
      const blob = new Blob([content], { type: "text/csv;charset=utf-8;" })
      const url = URL.createObjectURL(blob)
      const link = document.createElement("a")
      link.href = url
      link.download = filename
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
    })
  }
}
```

- [ ] **Step 2: Register in LiveSocket hooks**

Add `CsvDownload` to the hooks object in the `new LiveSocket(...)` call.

- [ ] **Step 3: Verify assets build**

```bash
cd assets && npm run deploy && cd ..
```

---

### Task 5: Reports Context Module — Operator Member Reports

**Files:**
- Create: `lib/fit_trackerz/reports.ex`

- [ ] **Step 1: Create the Reports module with the first 4 member reports**

Create `lib/fit_trackerz/reports.ex` with:
- `uuid` macro (same pattern as Analytics module)
- `active_members_report(gym_id, start_date, end_date, opts)` — summary: active/inactive/total. Rows: gym_members joined with users, paginated. Columns: name, email, phone, status, joined_at, trainer name.
- `new_members_report(gym_id, start_date, end_date, opts)` — summary: total new. Rows: gym_members where joined_at in range, joined with users. Columns: name, email, phone, joined_at.
- `revenue_report(gym_id, start_date, end_date, opts)` — summary: plan-wise breakdown + grand total. Rows: member_subscriptions where paid, joined with users + plans. Columns: member name, plan name, amount, payment_status, date.
- `attendance_report(gym_id, start_date, end_date, opts)` — summary: total check-ins, avg daily. Rows: attendance_records joined with gym_members + users. Columns: member name, email, date, time, marked_by.

Each function returns `%{summary: [...], rows: [...], total_count: int, columns: [...]}`.

Pagination via `opts[:page]` (default 1) and `opts[:per_page]` (default 10) using Ecto `offset/limit`.

Also include CSV variants: `active_members_csv(gym_id, ...)` etc. that return all rows unpaginated as a CSV string (summary header rows + blank line + column headers + data rows).

**Important:** Use the same `uuid()` macro and schemaless Ecto query pattern as `FitTrackerz.Analytics`. All enum values compared as strings (`^"paid"`, `^"active"`).

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 6: Reports Context — Remaining Operator Member Reports

**Files:**
- Modify: `lib/fit_trackerz/reports.ex`

- [ ] **Step 1: Add the remaining 4 member reports**

- `subscription_status_report(gym_id, start_date, end_date, opts)` — summary: active/expired/cancelled counts. Rows: member_subscriptions joined with users + plans. Columns: member name, email, plan, status, starts, expires, payment_status.
- `class_utilization_report(gym_id, start_date, end_date, opts)` — summary: per-class bookings/capacity. Rows: class_bookings joined with scheduled_classes + class_definitions + gym_members + users. Columns: class name, member name, booking_status, scheduled date.
- `payment_collection_report(gym_id, start_date, end_date, opts)` — summary: paid count+amount, pending count, failed count, refunded count. Rows: member_subscriptions joined with users + plans. Columns: member name, plan, amount, payment_status, date.
- `member_retention_report(gym_id, start_date, end_date, opts)` — summary: active count, churned count, retention rate %. Rows: gym_members joined with users, showing all with status + last attendance. Columns: name, email, phone, status, joined_at, last_attendance_date.

Plus CSV variants for each.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 7: Reports Context — Operator Trainer Performance Reports

**Files:**
- Modify: `lib/fit_trackerz/reports.ex`

- [ ] **Step 1: Add 4 trainer performance reports**

- `trainer_overview_report(gym_id, start_date, end_date, opts)` — summary: per-trainer aggregates. Rows: gym_trainers joined with users, with subquery counts for clients, classes, attendance. Columns: trainer name, email, specializations, active_clients, classes_taught, attendance_marked.
- `trainer_client_load_report(gym_id, start_date, end_date, opts)` — summary: per-trainer active/inactive. Rows: gym_members joined with assigned trainer + user. Columns: trainer name, client name, client status, subscription_status, joined_at.
- `trainer_class_performance_report(gym_id, start_date, end_date, opts)` — summary: per-trainer classes/bookings/utilization. Rows: scheduled_classes joined with trainer + class_definition + booking counts. Columns: trainer name, class name, date, bookings, capacity, utilization %.
- `trainer_attendance_report(gym_id, start_date, end_date, opts)` — summary: per-trainer client check-ins. Rows: attendance grouped by trainer's clients. Columns: trainer name, client name, check-ins in period, last check-in date.

Plus CSV variants.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 8: Reports Context — Trainer Self Reports

**Files:**
- Modify: `lib/fit_trackerz/reports.ex`

- [ ] **Step 1: Add 6 trainer self-reports**

All scoped by `trainer_id` (the gym_trainer.id) to get only assigned clients.

- `my_clients_report(gym_id, trainer_id, start_date, end_date, opts)` — summary: active/inactive/total. Rows: assigned gym_members + users. Columns: client name, email, phone, status, subscription, joined_at.
- `client_attendance_report(gym_id, trainer_id, start_date, end_date, opts)` — summary: total check-ins, avg daily. Rows: attendance_records for trainer's clients. Columns: client name, check-in date, time, notes.
- `client_subscriptions_report(gym_id, trainer_id, start_date, end_date, opts)` — summary: active/expired/cancelled. Rows: member_subscriptions for trainer's clients. Columns: client name, plan, status, payment, starts, expires.
- `workout_plans_report(gym_id, trainer_id, start_date, end_date, opts)` — summary: total plans, active. Rows: workout_plans by trainer. Columns: client name, plan name, created_at, exercises count.
- `diet_plans_report(gym_id, trainer_id, start_date, end_date, opts)` — summary: total, by dietary_type. Rows: diet_plans by trainer. Columns: client name, plan name, dietary_type, calorie_target, created_at.
- `my_classes_report(gym_id, trainer_id, start_date, end_date, opts)` — summary: total, completed, bookings. Rows: scheduled_classes by trainer. Columns: class name, date, status, bookings, capacity.

Plus CSV variants.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 9: Operator Report List Page

**Files:**
- Create: `lib/fit_trackerz_web/live/gym_operator/reports_live.ex`

- [ ] **Step 1: Create the report list page**

A grid of cards showing all 12 predefined reports, organized in two sections: "Member Reports" (8) and "Trainer Performance Reports" (4).

Each card shows: icon, report name, brief description. Click navigates to `/gym/reports/:report_type`.

Report definitions as a module attribute:

```elixir
@member_reports [
  %{type: "active_members", name: "Active Members", desc: "Active vs inactive member breakdown", icon: "hero-user-group-solid"},
  %{type: "new_members", name: "New Members", desc: "Members who joined in the selected period", icon: "hero-user-plus-solid"},
  %{type: "revenue", name: "Revenue", desc: "Plan-wise revenue from paid subscriptions", icon: "hero-currency-rupee-solid"},
  %{type: "attendance", name: "Attendance", desc: "Member check-in records and trends", icon: "hero-clipboard-document-check-solid"},
  %{type: "subscription_status", name: "Subscription Status", desc: "Subscription status breakdown", icon: "hero-credit-card-solid"},
  %{type: "class_utilization", name: "Class Utilization", desc: "Class bookings vs capacity", icon: "hero-calendar-days-solid"},
  %{type: "payment_collection", name: "Payment Collection", desc: "Payment status breakdown with amounts", icon: "hero-banknotes-solid"},
  %{type: "member_retention", name: "Member Retention", desc: "Active vs churned members", icon: "hero-arrow-trending-up-solid"}
]

@trainer_reports [
  %{type: "trainer_overview", name: "Trainer Overview", desc: "Summary of all trainers' performance", icon: "hero-academic-cap-solid"},
  %{type: "trainer_client_load", name: "Trainer Client Load", desc: "Client distribution across trainers", icon: "hero-users-solid"},
  %{type: "trainer_class_performance", name: "Trainer Class Performance", desc: "Class teaching performance per trainer", icon: "hero-chart-bar-solid"},
  %{type: "trainer_attendance", name: "Trainer Attendance Impact", desc: "Client attendance per trainer", icon: "hero-clipboard-document-check-solid"}
]
```

Render: DaisyUI card grid, 2 cols desktop, 1 mobile. Section headers. Each card is a link to the detail page.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 10: Operator Report Detail Page

**Files:**
- Create: `lib/fit_trackerz_web/live/gym_operator/report_detail_live.ex`

- [ ] **Step 1: Create the report detail page**

This is the core report view page. It handles all 12 report types via the `:report_type` URL param.

**Mount/handle_params:**
- Extract `report_type` from params
- Load gym
- Default 30-day range
- Call the appropriate `FitTrackerz.Reports.*_report()` function
- Assign: report_data (summary + rows + total_count + columns), page, per_page, report_type, report_name

**Events:**
- `select_preset` / `apply_custom_range` — same date range logic as dashboards
- `change_page` — update page number, re-query
- `change_per_page` — update per_page, reset to page 1, re-query
- `export_csv` — call the CSV variant, push_event to CsvDownload hook

**Report dispatcher** — a private function that maps report_type string to the correct Reports function:

```elixir
defp load_report("active_members", gym_id, s, e, opts), do: Reports.active_members_report(gym_id, s, e, opts)
defp load_report("new_members", gym_id, s, e, opts), do: Reports.new_members_report(gym_id, s, e, opts)
# ... for all 12 types
```

**Render:**
1. Header with report name + "Back to Reports" link + "Export CSV" button
2. Date range controls (presets + custom)
3. Summary table — iterate `report_data.summary`, render as rows in a table
4. Detail table:
   - "Showing X to Y of Z records" header
   - Rows per page selector (10/25/50)
   - Table with S.No + columns from `report_data.columns`
   - Status badge rendering for known status fields
   - Pagination footer: Previous / Page X of Y / Next

**The CsvDownload hook** must be attached to the page: add `id="csv-download" phx-hook="CsvDownload"` to a hidden div.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 11: Trainer Report List Page

**Files:**
- Create: `lib/fit_trackerz_web/live/trainer/reports_live.ex`

- [ ] **Step 1: Create trainer report list page**

Same pattern as operator report list but with 6 trainer-specific reports:

```elixir
@reports [
  %{type: "my_clients", name: "My Clients", desc: "Your assigned clients overview", icon: "hero-user-group-solid"},
  %{type: "client_attendance", name: "Client Attendance", desc: "Check-in records for your clients", icon: "hero-clipboard-document-check-solid"},
  %{type: "client_subscriptions", name: "Client Subscriptions", desc: "Subscription status of your clients", icon: "hero-credit-card-solid"},
  %{type: "workout_plans", name: "Workout Plans", desc: "Workout plans you've created", icon: "hero-fire-solid"},
  %{type: "diet_plans", name: "Diet Plans", desc: "Diet plans you've assigned", icon: "hero-heart-solid"},
  %{type: "my_classes", name: "My Classes", desc: "Classes you've taught", icon: "hero-calendar-days-solid"}
]
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 12: Trainer Report Detail Page

**Files:**
- Create: `lib/fit_trackerz_web/live/trainer/report_detail_live.ex`

- [ ] **Step 1: Create trainer report detail page**

Same pattern as operator report detail but:
- Load gym and gym_trainer via `list_active_trainerships`
- Pass `trainer_id: gym_trainer.id` in opts to report functions
- Dispatcher maps to trainer-scoped report functions:

```elixir
defp load_report("my_clients", gym_id, s, e, opts), do: Reports.my_clients_report(gym_id, opts[:trainer_id], s, e, opts)
# ... for all 6 types
```

- The render template is identical in structure (summary table + paginated detail table + CSV export)
- "Back to Reports" links to `/trainer/reports`

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 13: Full Compilation + Smoke Test

- [ ] **Step 1: Full compilation**

```bash
mix compile --warnings-as-errors
```

- [ ] **Step 2: Smoke test**

1. Sign in as gym operator
2. Verify sidebar shows "Dashboards" (not Analytics) and "Reports"
3. Navigate to `/gym/dashboards` — verify charts load, test viz dropdown (switch to Bar, Table, back to Line)
4. Navigate to `/gym/reports` — verify 12 report cards show (8 member + 4 trainer)
5. Click "Active Members" report — verify summary table + paginated member list
6. Change date range — data updates
7. Change rows per page (10/25/50) — pagination updates
8. Click Export CSV — file downloads
9. Click a trainer performance report — verify trainer data
10. Sign in as trainer
11. Navigate to `/trainer/reports` — verify 6 report cards
12. Click "My Clients" — verify scoped to trainer's clients only
13. Test CSV export from trainer report
